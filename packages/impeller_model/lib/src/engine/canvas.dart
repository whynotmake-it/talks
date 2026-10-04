/// A Dart port of the pass-structure decisions of `impeller::Canvas`
/// (impeller/display_list/canvas.cc): when a render pass starts, ends,
/// restarts, or spawns filter passes.
///
/// Scope:
///  - All geometry is pre-transformed into root space, so the engine's
///    transform stack collapses to identity and coverage uses AABBs.
///  - Depth/stencil clipping is not modeled. Clips only narrow coverage
///    limits, as `ClipCoverage` bounding boxes do in the engine.
///  - Draw calls are counted, not rendered. Only blend mode, filters and
///    bounds matter for pass decisions.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show Rect;

import '../capture/recorded_op.dart';
import 'capabilities.dart';
import 'gaussian_blur.dart';
import 'labels.dart';
import 'ops.dart';

/// Why a pass exists. Every value maps to one code path in canvas.cc.
enum PassRole {
  onscreenRoot(
    'Frame',
    'Draws the frame straight into the screen surface.',
  ),
  offscreenRoot(
    'Offscreen frame',
    'The frame starts offscreen because something in it must read back '
        'what was drawn (a backdrop filter, or an advanced blend without '
        'framebuffer fetch). It is copied to the screen at the end.',
  ),
  onscreenAfterFlip(
    'Frame (continued on screen)',
    'After the last backdrop filter, drawing continues directly in the '
        'screen surface. It starts by redrawing everything drawn so far.',
  ),
  restartAfterFlip(
    'Restarted pass',
    'A backdrop filter or emulated blend had to read this pass, so the '
        'pass was ended and stored. Drawing continues in a new pass that '
        'first redraws the stored texture.',
  ),
  saveLayer(
    'Layer',
    'An offscreen layer (saveLayer). Its content is drawn into its own '
        'texture, then composited into the parent pass.',
  ),
  blurDownsample(
    'Blur: downsample',
    'First of three Gaussian blur passes: shrinks the input.',
  ),
  blurY('Blur: vertical', 'Second Gaussian blur pass.'),
  blurX('Blur: horizontal', 'Third Gaussian blur pass.'),
  morphology('Dilate/erode', 'One direction of a morphology filter.'),
  filterInputSnapshot(
    'Filter input',
    'Renders a filter input that is not yet a texture (e.g. a color '
        'filter feeding a blur) into one.',
  ),
  blendSourceSnapshot(
    'Blend source',
    'An advanced blend mode first renders the drawn shape into a texture, '
        'then blends it (in the current pass with framebuffer fetch, in an '
        'emulated blend pass without).',
  ),
  filter('Filter', 'An image filter the model does not port in detail.'),
  advancedBlend(
    'Emulated blend',
    'An advanced blend mode without framebuffer fetch: blends the stored '
        'backdrop with the source into an intermediate texture.',
  ),
  copyToOnscreen(
    'Copy to screen',
    'Copies the offscreen frame to the screen with a render pass '
        '(non-Metal backends).',
  ),
  blitToOnscreen(
    'Blit to screen',
    'Copies the offscreen frame to the screen with a blit (Metal). Not a '
        'render pass.',
  );

  const PassRole(this.title, this.explanation);
  final String title;
  final String explanation;

  static PassRole fromFilterKind(FilterPassKind kind) => switch (kind) {
    FilterPassKind.blurDownsample => blurDownsample,
    FilterPassKind.blurY => blurY,
    FilterPassKind.blurX => blurX,
    FilterPassKind.morphology => morphology,
    FilterPassKind.inputSnapshot => filterInputSnapshot,
    FilterPassKind.unknownFilter => filter,
  };
}

/// One unit of GPU work in the estimated frame: a render pass, or the final
/// blit.
class ModelPass {
  ModelPass({
    required this.role,
    required this.engineLabel,
    required this.size,
    this.commandBufferLabel,
    this.cause,
    this.endedBy,
    this.writesSurface = false,
    this.inputReadArea = 0,
    this.approximate = false,
  });

  final PassRole role;

  /// The label a GPU capture shows for this encoder (see [EngineLabels]).
  final String engineLabel;

  /// The label of the command buffer it is encoded into, when Impeller sets
  /// one. Filter passes run in unlabeled command buffers.
  final String? commandBufferLabel;

  /// Target texture size in physical pixels.
  final ui.Size size;

  /// The layer or widget that caused the pass, when known.
  final String? cause;

  /// The backdrop filter or blend that ended this pass early to read it
  /// back. Without it the pass would have continued, so its store and
  /// readback are charged to [endedBy].
  final String? endedBy;

  /// Who this pass's traffic is charged to.
  String get chargedTo => endedBy ?? cause ?? role.title;

  /// True when the pass writes the screen surface. That write is the cost
  /// of any frame, not an extra.
  final bool writesSurface;

  /// Extra full-resolution pixel area this pass samples beyond its
  /// predecessor's texture (the blur downsample reads its whole source).
  final double inputReadArea;

  /// True when the pass shape is not ported, only guessed.
  final bool approximate;

  int drawCount = 0;

  /// Index of the pass this one was spawned from, if any.
  int? parent;
  _Pass? _parentPass;

  bool get isRenderPass => role != PassRole.blitToOnscreen;

  /// Bytes written to memory when this pass ends. MSAA samples never are:
  /// offscreen MSAA attachments are memoryless/transient and resolved on
  /// store.
  ///
  /// ```engine impeller/display_list/canvas.cc
  ///         RenderTarget::AttachmentConfigMSAA{
  ///             .storage_mode = StorageMode::kDeviceTransient,
  ///             .resolve_storage_mode = StorageMode::kDevicePrivate,
  ///             .load_action = LoadAction::kDontCare,
  ///             .store_action = StoreAction::kMultisampleResolve,
  /// ```
  int storedBytes(int bytesPerPixel) => writesSurface || !isRenderPass
      ? 0
      : (size.width * size.height * bytesPerPixel).round();

  /// Bytes read back because of this pass: its own stored texture is read
  /// once by whoever consumes it, plus any extra input it samples.
  int readBytes(int bytesPerPixel) =>
      storedBytes(bytesPerPixel) + (inputReadArea * bytesPerPixel).round();

  Map<String, Object?> toJson() => {
    'role': role.name,
    'engineLabel': engineLabel,
    if (commandBufferLabel != null) 'commandBuffer': commandBufferLabel,
    'size': [size.width, size.height],
    if (cause != null) 'cause': cause,
    if (endedBy != null) 'endedBy': endedBy,
    'drawCount': drawCount,
    if (parent != null) 'parent': parent,
    if (writesSurface) 'writesSurface': true,
    if (!isRenderPass) 'isBlit': true,
    if (approximate) 'approximate': true,
  };
}

/// The replay result: passes in the order they end (the order their
/// command buffers are committed), plus totals.
class PassTimeline {
  PassTimeline({required this.passes, required this.profile});

  final List<ModelPass> passes;
  final CapabilityProfile profile;
  int flips = 0;

  /// Passes left open at endReplay (unbalanced op stream).
  int unclosedPasses = 0;

  /// Render passes only. The blit is not one and would not appear as a
  /// render encoder in a capture.
  int get renderPassCount => passes.where((p) => p.isRenderPass).length;

  /// Render pass count per engine label, which is what to compare against a
  /// GPU capture or a Metal System Trace.
  Map<String, int> get renderPassesByLabel {
    final m = <String, int>{};
    for (final p in passes.where((p) => p.isRenderPass)) {
      m[p.engineLabel] = (m[p.engineLabel] ?? 0) + 1;
    }
    return m;
  }

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'renderPassCount': renderPassCount,
    'renderPassesByLabel': renderPassesByLabel,
    'flips': flips,
    if (unclosedPasses > 0) 'unclosedPasses': unclosedPasses,
    'passes': passes.map((p) => p.toJson()).toList(),
  };
}

class _Pass {
  _Pass({
    required this.size,
    required this.origin,
    required this.role,
    this.cause,
    this.parent,
    this.writesSurface = false,
  });

  final ui.Size size;

  /// `GetGlobalPassPosition`: origin of the pass texture in root space.
  final ui.Offset origin;
  final PassRole role;
  final String? cause;
  final _Pass? parent;
  final bool writesSurface;
  String? endedBy;
  int drawCount = 0;
  int emitIndex = -1;

  Rect get rect => Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
}

class _StackEntry {
  _StackEntry({this.skipping = false, this.isSubpass = false});
  final bool skipping;
  final bool isSubpass;
}

class _SaveLayerState {
  _SaveLayerState(this.paint, this.coverage, this.ctmScale, this.cause);
  final MPaint paint;
  final Rect coverage;
  final ui.Size ctmScale;
  final String cause;
}

/// `Canvas::BackdropData`.
class _BackdropData {
  int backdropCount = 1;
  bool allFiltersEqual = true;
  FilterDesc? lastFilter;
  bool textureCached = false;
  bool sharedSnapshotComputed = false;
}

class ImpellerCanvasReplay {
  ImpellerCanvasReplay({
    required this.profile,
    required this.screenSize,
    required this.rootHasBackdropFilter,
    required this.maxRootBlendMode,
  }) {
    // The dispatcher decides up front whether the root must be offscreen:
    //
    // ```engine impeller/display_list/dl_dispatcher.cc
    //               has_root_backdrop_filter ||
    //                   RequiresReadbackForBlends(renderer, max_root_blend_mode),
    // ```
    // ```engine impeller/display_list/dl_dispatcher.cc
    // static bool RequiresReadbackForBlends(
    //     const ContentContext& renderer,
    //     flutter::DlBlendMode max_root_blend_mode) {
    //   return !renderer.GetDeviceCapabilities().SupportsFramebufferFetch() &&
    //          max_root_blend_mode > Entity::kLastPipelineBlendMode;
    // ```
    _requiresReadback =
        rootHasBackdropFilter ||
        (!profile.supportsFramebufferFetch &&
            isAdvancedBlend(maxRootBlendMode));
    // ```engine impeller/display_list/canvas.cc
    //   if (requires_readback_) {
    //     auto entity_pass_target =
    //         CreateRenderTarget(renderer_,                  //
    //                            color0.texture->GetSize(),  //
    //                            /*clear_color=*/Color::BlackTransparent());
    // ```
    _passes.add(
      _Pass(
        size: screenSize,
        origin: ui.Offset.zero,
        role: _requiresReadback
            ? PassRole.offscreenRoot
            : PassRole.onscreenRoot,
        cause: !_requiresReadback
            ? null
            : rootHasBackdropFilter
            ? 'backdrop filter (frame drawn offscreen)'
            : '${maxRootBlendMode.name} blend without framebuffer fetch',
        writesSurface: !_requiresReadback,
      ),
    );
    _clipCoverage = _screenRect;
  }

  final CapabilityProfile profile;
  final ui.Size screenSize;
  final bool rootHasBackdropFilter;
  final ui.BlendMode maxRootBlendMode;

  final List<_Pass> _passes = [];
  final List<_StackEntry> _stack = [_StackEntry()];
  final List<Rect> _clipStack = [];
  final List<_SaveLayerState> _saveLayerStates = [];
  final Map<int, _BackdropData> _backdropData = {};
  final List<ModelPass> _emitted = [];
  late bool _requiresReadback;
  int _backdropCountRemaining = 0;
  int _flips = 0;
  int _unclosedPasses = 0;
  late Rect _clipCoverage;

  Rect get _screenRect =>
      Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
  bool get _skipping => _stack.last.skipping;

  /// Register one backdrop saveLayer op before replay, as the dispatcher's
  /// pre-pass does. Every backdrop counts toward the total; keyed ones
  /// (BackdropGroup) also get per-key data.
  ///
  /// ```engine impeller/display_list/dl_dispatcher.cc
  ///   backdrop_count_ += (backdrop == nullptr ? 0 : 1);
  /// ```
  void registerBackdrop(int? backdropId, FilterDesc filter) {
    _backdropCountRemaining++;
    if (backdropId == null) {
      return;
    }
    final existing = _backdropData[backdropId];
    if (existing == null) {
      _backdropData[backdropId] = _BackdropData()..lastFilter = filter;
    } else {
      existing.backdropCount++;
      if (!existing.lastFilter!.isSameFilter(filter)) {
        existing.allFiltersEqual = false;
      }
      existing.lastFilter = filter;
    }
  }

  void save() {
    if (_skipping) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }
    _stack.add(_StackEntry());
    _clipStack.add(_clipCoverage);
  }

  /// `Canvas::SaveLayer`.
  void saveLayer({
    required MPaint paint,
    required bool canDistributeOpacity,
    required bool mayClipContents,
    Rect? bounds,
    FilterDesc? backdropFilter,
    int? backdropId,
    String debugLabel = 'saveLayer',
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    if (_skipping) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }

    // ```engine impeller/display_list/canvas.cc
    //   std::optional<Rect> maybe_coverage_limit =
    //       Rect::MakeOriginSize(GetGlobalPassPosition(),
    //                            Size(back_texture->GetSize()))
    //           .Intersection(current_clip_coverage);
    // ```
    final coverageLimit = _clipCoverage
        .intersect(_passes.last.rect)
        .intersect(_screenRect);
    if (coverageLimit.isEmpty) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }

    // The opacity peephole: no pass, the alpha is distributed to children.
    //
    // ```engine impeller/display_list/canvas.cc
    //   if (can_distribute_opacity && !backdrop_filter &&
    //       Paint::CanApplyOpacityPeephole(paint) &&
    //       bounds_promise != ContentBoundsPromise::kMayClipContents) {
    // ```
    if (canDistributeOpacity &&
        backdropFilter == null &&
        paint.canApplyOpacityPeephole &&
        !mayClipContents) {
      save();
      return;
    }

    // ```engine impeller/display_list/canvas.cc
    //       /*flood_output_coverage=*/
    //       Entity::IsBlendModeDestructive(paint.blend_mode),  //
    //       /*flood_input_coverage=*/!!backdrop_filter ||
    //           (paint.color_filter &&
    //            paint.color_filter->modifies_transparent_black())  //
    // ```
    final coverage = _computeSaveLayerCoverage(
      bounds,
      coverageLimit,
      paint.imageFilter,
      floodOutputCoverage: isBlendModeDestructive(paint.blendMode),
      floodInputCoverage:
          backdropFilter != null || paint.colorFilterAffectsTransparentBlack,
      ctmScale: ctmScale,
    );
    if (coverage == null || coverage.isEmpty) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }

    // ```engine impeller/display_list/canvas.cc
    //   if (paint.image_filter) {
    //     subpass_size = ISize(subpass_coverage.GetSize());
    //   } else {
    //     did_round_out = true;
    //     subpass_size =
    //         static_cast<ISize>(IRect::RoundOut(subpass_coverage).GetSize());
    // ```
    final ui.Size subpassSize;
    if (paint.imageFilter != null) {
      subpassSize = ui.Size(
        coverage.width.truncateToDouble(),
        coverage.height.truncateToDouble(),
      );
    } else {
      subpassSize = ui.Size(
        (coverage.right.ceil() - coverage.left.floor()).toDouble(),
        (coverage.bottom.ceil() - coverage.top.floor()).toDouble(),
      );
    }
    if (subpassSize.width <= 0 || subpassSize.height <= 0) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }
    final clamped = ui.Size(
      math.min(subpassSize.width, profile.maxAttachmentSize.toDouble()),
      math.min(subpassSize.height, profile.maxAttachmentSize.toDouble()),
    );

    var backdropInSubpass = false;
    Rect? flippedPassRect;
    if (backdropFilter != null) {
      var willCacheBackdrop = false;
      _BackdropData? data;
      var backdropCount = 1;
      // ```engine impeller/display_list/canvas.cc
      //         will_cache_backdrop_texture =
      //             backdrop_data_it->second.backdrop_count > 1;
      // ```
      if (backdropId != null) {
        data = _backdropData[backdropId];
        if (data != null) {
          willCacheBackdrop = data.backdropCount > 1;
          backdropCount = data.backdropCount;
        }
      }

      if (!willCacheBackdrop || !(data?.textureCached ?? false)) {
        _backdropCountRemaining -= backdropCount;
        // ```engine impeller/display_list/canvas.cc
        //       const bool should_use_onscreen =
        //           renderer_.GetDeviceCapabilities().SupportsFramebufferFetch() &&
        //           backdrop_count_ == 0 && render_passes_.size() == 1u;
        // ```
        final shouldUseOnscreen =
            profile.supportsFramebufferFetch &&
            _backdropCountRemaining == 0 &&
            _passes.length == 1;
        flippedPassRect = _passes.last.rect;
        _flipBackdrop(shouldUseOnscreen: shouldUseOnscreen, cause: debugLabel);
        if (willCacheBackdrop) {
          data?.textureCached = true;
        }
      }
      flippedPassRect ??= _passes.last.rect;

      // BackdropGroup with identical filters: the filter runs once for the
      // whole group, and each member draws the shared snapshot straight
      // into the current pass. No subpass for the member.
      //
      // ```engine impeller/display_list/canvas.cc
      //       if (backdrop_data->all_filters_equal &&
      //           !backdrop_data->shared_filter_snapshot.has_value()) {
      //         // TODO(157110): compute minimum input hint.
      //         backdrop_data->shared_filter_snapshot =
      //             backdrop_filter_contents->RenderToSnapshot(renderer_, {}, {});
      //       }
      // ```
      if (willCacheBackdrop && (data?.allFiltersEqual ?? false)) {
        if (data != null && !data.sharedSnapshotComputed) {
          // No coverage hint: the snapshot covers the whole flipped texture.
          _emitFilterPasses(
            backdropFilter,
            input: flippedPassRect,
            coverageHint: null,
            ctmScale: ctmScale,
            cause: 'shared by BackdropGroup: $debugLabel',
          );
          data.sharedSnapshotComputed = true;
        }
        _passes.last.drawCount++;
        save();
        return;
      }
      backdropInSubpass = true;
    }

    _passes.add(
      _Pass(
        size: clamped,
        origin: coverage.topLeft,
        role: PassRole.saveLayer,
        cause: debugLabel,
        parent: _passes.last,
      ),
    );
    _saveLayerStates.add(
      _SaveLayerState(paint, coverage, ctmScale, debugLabel),
    );
    _stack.add(_StackEntry(isSubpass: true));
    // ```engine impeller/display_list/canvas.cc
    //   clip_coverage_stack_.PushSubpass(subpass_coverage, GetClipHeight());
    // ```
    _clipStack.add(_clipCoverage);
    _clipCoverage = coverage;

    if (backdropInSubpass) {
      // The filtered backdrop is the first thing drawn into the new subpass.
      //
      // ```engine impeller/display_list/canvas.cc
      //   // Render the backdrop entity.
      //   Entity backdrop_entity;
      //   backdrop_entity.SetContents(std::move(backdrop_filter_contents));
      // ```
      _emitFilterPasses(
        backdropFilter!,
        input: flippedPassRect!,
        coverageHint: coverage,
        ctmScale: ctmScale,
        cause: debugLabel,
      );
      _passes.last.drawCount++;
    }
  }

  void clip(Rect coverage, {bool isDifference = false}) {
    if (_skipping || isDifference) {
      // A difference clip never shrinks the coverage bounding box.
      return;
    }
    _clipCoverage = _clipCoverage.intersect(coverage);
  }

  /// A draw op reaching `AddRenderEntityToCurrentPass`.
  void draw({
    required ui.BlendMode blendMode,
    Rect? bounds,
    FilterDesc? imageFilter,
    FilterDesc? maskBlur,
    ui.Size ctmScale = const ui.Size(1, 1),
    String name = 'draw',
  }) {
    if (_skipping) {
      return;
    }
    // A Paint.imageFilter (or a mask blur that misses the shadow fast path)
    // filters the draw's own contents:
    //
    // ```engine impeller/display_list/canvas.cc
    //   if (paint.image_filter) {
    //     std::shared_ptr<FilterContents> filter =
    //         WrapInput(renderer_, paint.image_filter,
    //                   FilterInput::Make(std::move(contents_copy)));
    // ```
    for (final filter in [?maskBlur, ?imageFilter]) {
      final input = bounds ?? _clipCoverage;
      _emitFilterPasses(
        filter,
        input: input,
        coverageHint: null,
        ctmScale: ctmScale,
        cause: name,
      );
    }
    // ```engine impeller/display_list/canvas.cc
    //   if (entity.GetBlendMode() > Entity::kLastPipelineBlendMode) {
    //     if (renderer_.GetDeviceCapabilities().SupportsFramebufferFetch()) {
    //       ApplyFramebufferBlend(entity);
    //     } else {
    // ```
    // With framebuffer fetch the blend stays in the pass, but its source is
    // rendered to a texture first:
    //
    // ```engine impeller/entity/contents/framebuffer_blend_contents.cc
    //   auto src_snapshot = child_contents_->RenderToSnapshot(
    //       renderer, entity,
    //       {.coverage_limit = Rect::MakeSize(pass.GetRenderTargetSize()),
    // ```
    //
    // (A saveLayer restored with an advanced blend is already a texture,
    // which TextureContents::RenderToSnapshot passes through: no pass.)
    if (isAdvancedBlend(blendMode) && profile.supportsFramebufferFetch) {
      final cov = (bounds ?? _clipCoverage).intersect(_passes.last.rect);
      if (!cov.isEmpty) {
        _emitted.add(
          ModelPass(
              role: PassRole.blendSourceSnapshot,
              engineLabel: EngineLabels.framebufferBlendSnapshot,
              size: _roundOut(cov),
              cause: '$name (${blendMode.name})',
            )
            ..drawCount = 1
            .._parentPass = _passes.last,
        );
      }
    }
    if (isAdvancedBlend(blendMode) && !profile.supportsFramebufferFetch) {
      _flipBackdrop(cause: '$name (${blendMode.name})');
      // ```engine impeller/display_list/canvas.cc
      //       entity.GetContents()->SetCoverageHint(Rect::Intersection(
      //           element_coverage_hint, clip_coverage_stack_.CurrentClipCoverage()));
      // ```
      final cov = bounds?.intersect(_clipCoverage);
      final blendRect = cov == null || cov.isEmpty ? _passes.last.rect : cov;
      // The source draw is not a texture yet, so it is rendered into one.
      _emitted.add(
        ModelPass(
            role: PassRole.blendSourceSnapshot,
            engineLabel: EngineLabels.advancedBlendSourceSnapshot,
            size: _roundOut(blendRect),
            cause: '$name (${blendMode.name})',
          )
          ..drawCount = 1
          .._parentPass = _passes.last,
      );
      _emitBlendPass(blendRect, '$name (${blendMode.name})');
    }
    _passes.last.drawCount++;
  }

  /// `Canvas::Restore`.
  void restore() {
    if (_stack.length == 1) {
      return;
    }
    final entry = _stack.removeLast();
    if (entry.skipping) {
      return;
    }
    _clipCoverage = _clipStack.removeLast();
    if (!entry.isSubpass) {
      return;
    }
    // ```engine impeller/display_list/canvas.cc
    //     std::shared_ptr<Contents> contents = CreateContentsForSubpassTarget(
    //         renderer_, save_layer_state.paint,                         //
    //         lazy_render_pass.GetInlinePassContext()->GetTexture(),     //
    //         Matrix::MakeTranslation(Vector3{-global_pass_position}) *  //
    //             transform_stack_.back().transform                      //
    //     );
    //
    //     lazy_render_pass.GetInlinePassContext()->EndPass();
    // ```
    _finishPass(_passes.removeLast());
    final state = _saveLayerStates.removeLast();

    // The saveLayer's own image filter runs when its texture is composited.
    final filter = state.paint.imageFilter;
    if (filter != null) {
      _emitFilterPasses(
        filter,
        input: state.coverage,
        coverageHint: null,
        ctmScale: state.ctmScale,
        cause: state.cause,
      );
    }

    // ```engine impeller/display_list/canvas.cc
    //     if (element_entity.GetBlendMode() > Entity::kLastPipelineBlendMode) {
    //       if (renderer_.GetDeviceCapabilities().SupportsFramebufferFetch()) {
    //         ApplyFramebufferBlend(element_entity);
    //       } else {
    // ```
    if (isAdvancedBlend(state.paint.blendMode) &&
        !profile.supportsFramebufferFetch) {
      _flipBackdrop(cause: state.cause);
      // ```engine impeller/display_list/canvas.cc
      //         contents->SetCoverageHint(element_entity.GetCoverage());
      // ```
      _emitBlendPass(state.coverage, state.cause);
    }
    _passes.last.drawCount++;
  }

  /// `Canvas::EndReplay`.
  PassTimeline endReplay() {
    while (_passes.length > 1) {
      _unclosedPasses++;
      _finishPass(_passes.removeLast());
    }
    _finishPass(_passes.removeLast());
    // ```engine impeller/display_list/canvas.cc
    //   if (requires_readback_) {
    //     BlitToOnscreen(/*is_onscreen_=*/is_onscreen_);
    //   }
    // ```
    if (_requiresReadback) {
      if (profile.supportsBlitToOnscreen) {
        _emitted.add(
          ModelPass(
            role: PassRole.blitToOnscreen,
            engineLabel: EngineLabels.blitToOnscreen,
            commandBufferLabel: EngineLabels.rootCommandBuffer,
            size: screenSize,
            writesSurface: true,
          ),
        );
      } else {
        _emitted.add(
          ModelPass(
            role: PassRole.copyToOnscreen,
            engineLabel: EngineLabels.rootCopyPass,
            commandBufferLabel: EngineLabels.rootCommandBuffer,
            size: screenSize,
            writesSurface: true,
          )..drawCount = 1,
        );
      }
    }
    for (final p in _emitted) {
      final i = p._parentPass?.emitIndex ?? -1;
      p.parent = i >= 0 ? i : null;
    }
    return PassTimeline(passes: _emitted, profile: profile)
      ..flips = _flips
      ..unclosedPasses = _unclosedPasses;
  }

  void _finishPass(_Pass p) {
    p.emitIndex = _emitted.length;
    _emitted.add(
      ModelPass(
          role: p.role,
          engineLabel: EngineLabels.entityPass,
          commandBufferLabel: EngineLabels.entityPassCommandBuffer,
          size: p.size,
          cause: p.cause,
          endedBy: p.endedBy,
          writesSurface: p.writesSurface,
        )
        ..drawCount = p.drawCount
        .._parentPass = p.parent,
    );
  }

  /// `Canvas::FlipBackdrop`: ends the current pass so its texture can be
  /// read, then continues in a new pass that redraws it.
  ///
  /// ```engine impeller/display_list/canvas.cc
  ///   rendering_config.GetInlinePassContext()->GetRenderPass();
  ///   if (!rendering_config.GetInlinePassContext()->EndPass()) {
  /// ```
  void _flipBackdrop({bool shouldUseOnscreen = false, String? cause}) {
    _flips++;
    final ended = _passes.removeLast()..endedBy = cause;
    _finishPass(ended);
    if (shouldUseOnscreen) {
      // ```engine impeller/display_list/canvas.cc
      //     render_passes_.push_back(
      //         LazyRenderingConfig(renderer_, std::move(entity_pass_target)));
      //     requires_readback_ = false;
      // ```
      _requiresReadback = false;
      _passes.add(
        _Pass(
          size: screenSize,
          origin: ui.Offset.zero,
          role: PassRole.onscreenAfterFlip,
          cause: cause,
          writesSurface: true,
        ),
      );
    } else {
      _passes.add(
        _Pass(
          size: ended.size,
          origin: ended.origin,
          role: PassRole.restartAfterFlip,
          cause: cause ?? ended.cause,
          parent: ended.parent,
        ),
      );
    }
    // ```engine impeller/display_list/canvas.cc
    //   msaa_backdrop_contents->SetLabel("MSAA backdrop");
    // ```
    _passes.last.drawCount = 1;
  }

  static ui.Size _roundOut(Rect r) => ui.Size(
    (r.right.ceil() - r.left.floor()).toDouble(),
    (r.bottom.ceil() - r.top.floor()).toDouble(),
  );

  /// The emulated blend samples the stored backdrop under [coverage] (its
  /// destination input) besides its source snapshot:
  ///
  /// ```engine impeller/entity/contents/filters/blend_filter_contents.cc
  ///   auto dst_snapshot =
  ///       inputs[0]->GetSnapshot("AdvancedBlend(Dst)", renderer, entity);
  /// ```
  void _emitBlendPass(Rect coverage, String cause) {
    _emitted.add(
      ModelPass(
          role: PassRole.advancedBlend,
          engineLabel: EngineLabels.advancedBlendFilter,
          size: coverage.size,
          cause: cause,
          inputReadArea: coverage.width * coverage.height,
        )
        ..drawCount = 1
        .._parentPass = _passes.last,
    );
  }

  void _emitFilterPasses(
    FilterDesc filter, {
    required Rect input,
    required Rect? coverageHint,
    required ui.Size ctmScale,
    required String cause,
  }) {
    final estimates = estimateFilterPasses(
      filter,
      input: input,
      coverageHint: coverageHint,
      basisScale: ctmScale,
    );
    for (final p in estimates) {
      _emitted.add(
        ModelPass(
            role: PassRole.fromFilterKind(p.kind),
            engineLabel: p.engineLabel,
            size: p.size,
            cause: cause,
            inputReadArea: p.inputReadArea,
            approximate: p.approximate,
          )
          ..drawCount = 1
          .._parentPass = _passes.isEmpty ? null : _passes.last,
      );
    }
  }

  /// `ComputeSaveLayerCoverage` (impeller/entity/save_layer_utils.cc).
  Rect? _computeSaveLayerCoverage(
    Rect? contentCoverage,
    Rect coverageLimit,
    FilterDesc? imageFilter, {
    required bool floodOutputCoverage,
    required bool floodInputCoverage,
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    // ```engine impeller/entity/save_layer_utils.cc
    //   if (flood_input_coverage) {
    //     coverage = Rect::MakeMaximum();
    //   }
    // ```
    var coverage = floodInputCoverage ? null : contentCoverage;
    if (imageFilter != null) {
      // ```engine impeller/entity/save_layer_utils.cc
      //     std::optional<Rect> source_coverage_limit =
      //         image_filter->GetSourceCoverage(effect_transform,
      //                                         coverage_limit);
      // ```
      final sourceLimit = _filterSourceCoverage(
        imageFilter,
        coverageLimit,
        ctmScale: ctmScale,
      );
      if (floodOutputCoverage || coverage == null) {
        return sourceLimit;
      }
      final intersected = coverage.intersect(sourceLimit);
      // ```engine impeller/entity/save_layer_utils.cc
      //     if (intersected_coverage.has_value() &&
      //         SizeDifferenceUnderThreshold(transformed_coverage.GetSize(),
      //                                      intersected_coverage->GetSize(),
      //                                      kDefaultSizeThreshold)) {
      // ```
      if (!intersected.isEmpty &&
          _sizeDifferenceUnderThreshold(coverage.size, intersected.size)) {
        return coverage;
      }
      return intersected.isEmpty ? null : intersected;
    }
    if (floodOutputCoverage || coverage == null) {
      return coverageLimit;
    }
    final intersected = coverage.intersect(coverageLimit);
    if (intersected.isEmpty) {
      return null;
    }
    // ```engine impeller/entity/save_layer_utils.cc
    //   if (SizeDifferenceUnderThreshold(intersect_rect.GetSize(),
    //                                    coverage_limit.GetSize(),
    //                                    kDefaultSizeThreshold)) {
    //     return coverage_limit;
    //   }
    // ```
    if (_sizeDifferenceUnderThreshold(intersected.size, coverageLimit.size)) {
      return coverageLimit;
    }
    return intersected;
  }

  /// ```engine impeller/entity/save_layer_utils.cc
  /// static constexpr Scalar kDefaultSizeThreshold = 0.3;
  /// ```
  static bool _sizeDifferenceUnderThreshold(ui.Size a, ui.Size b) =>
      ((a.width - b.width).abs() / b.width) < 0.3 &&
      ((a.height - b.height).abs() / b.height) < 0.3;

  /// `FilterContents::GetFilterSourceCoverage`: which input region a filter
  /// needs to produce `outputLimit`.
  Rect _filterSourceCoverage(
    FilterDesc filter,
    Rect outputLimit, {
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    if (filter.kind != 'blur') {
      return outputLimit;
    }
    // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
    //   Vector3 blur_radii =
    //       (effect_transform.Basis() * Vector3{blur_radius.x, blur_radius.y, 0.0})
    //           .Abs();
    //   return output_limit.Expand(Point(blur_radii.x, blur_radii.y));
    // ```
    final rx =
        calculateBlurRadius(math.min(scaleSigma(filter.sigmaX), kMaxSigma)) *
        ctmScale.width;
    final ry =
        calculateBlurRadius(math.min(scaleSigma(filter.sigmaY), kMaxSigma)) *
        ctmScale.height;
    return Rect.fromLTRB(
      outputLimit.left - rx,
      outputLimit.top - ry,
      outputLimit.right + rx,
      outputLimit.bottom + ry,
    );
  }
}
