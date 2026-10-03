import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show Rect;

import '../capture/recorded_op.dart';
import 'capabilities.dart';
import 'filters.dart';
import 'ops.dart';

/// A render pass as produced by the model. Mirrors the passes Impeller
/// records via `InlinePassContext` (one per "EntityPass Render Pass" label
/// in a GPU capture) plus standalone filter subpasses.
class ModelPass {
  ModelPass({
    required this.label,
    required this.size,
    required this.reason,
    this.parent,
    this.writesToSurface = false,
    this.isBlit = false,
  });

  /// Debug label comparable to what a GPU capture would show.
  String label;

  /// Texture size of the pass target, physical pixels.
  final ui.Size size;

  /// Why this pass exists (root / saveLayer / backdrop-flip restart /
  /// filter / blend / onscreen-blit).
  final String reason;

  /// Index of the pass that spawned this one, if any. Mutable: resolved
  /// after the owning pass finishes (children emit before parents).
  int? parent;

  /// Internal: the owning pass object, resolved to [parent] at endReplay.
  _Pass? _parentPass;

  /// True when this pass ends by writing the onscreen surface — its store
  /// is the frame's required output write, not break-induced traffic.
  final bool writesToSurface;

  /// True when this entry is a blit-encoder op, not a GPU render pass
  /// (Canvas::BlitToOnscreen, canvas.cc:2624). Kept out of renderPassCount
  /// so GPU-capture comparisons count real passes only.
  final bool isBlit;

  int drawCount = 0;

  /// MSAA sample count for this pass's target — blur/filter subpasses
  /// and blit ops run with msaa_enabled=false (gaussian_blur_filter_
  /// contents.cc), entity passes use the profile's.
  int msaaSamples = 1;

  /// Estimated bytes stored+loaded by ending this pass, using the talk's
  /// rule of thumb: a pass break flushes the whole target — w·h·4 bytes
  /// stored per MSAA sample plus one w·h·4 load+resolve. Blur/filter/blit
  /// targets run with msaa_enabled=false (msaa=1). This is an ESTIMATE —
  /// it ignores tiling, compression and partial coverage.
  int get estimatedTrafficBytes => writesToSurface
      ? 0
      : (size.width * size.height * 4 * (msaaSamples + 1)).round();

  Map<String, Object?> toJson() => {
    'label': label,
    'reason': reason,
    'size': [size.width, size.height],
    'drawCount': drawCount,
    'estTrafficBytes': estimatedTrafficBytes,
    if (parent != null) 'parent': parent,
    if (isBlit) 'isBlit': true,
  };
}

class _Pass {
  _Pass({
    required this.size,
    required this.origin,
    required this.isSubpass,
    required this.label,
    required this.reason,
    this.parent,
    this.writesToSurface = false,
    this.msaa = 1,
  });

  ui.Size size;

  /// `GetGlobalPassPosition` — origin of the pass texture in root space.
  ui.Offset origin;
  final bool isSubpass;
  String label;
  final String reason;

  /// The pass that spawned this one (e.g. the saveLayer's parent pass).
  /// Object ref because the parent's emit index isn't known until it
  /// finishes — resolved post-replay.
  final _Pass? parent;
  bool writesToSurface;
  int drawCount = 0;

  /// MSAA sample count — blur/blit/filter targets run with
  /// msaa_enabled=false; EntityPass targets use the profile's.
  int msaa;

  /// Position in [ModelReplay]'s emitted list; set at [_finishPass].
  int emitIndex = -1;

  /// The [ModelPass] produced by [_finishPass].
  ModelPass? modelPass;
}

class _StackEntry {
  _StackEntry({this.skipping = false, this.isSubpass = false});
  bool skipping;
  final bool isSubpass;
}

class _SaveLayerState {
  _SaveLayerState(this.paint, this.coverage, this.ctmScale);
  final MPaint paint;
  final Rect coverage;
  final ui.Size ctmScale;
}

class _BackdropData {
  int backdropCount = 1;
  bool allFiltersEqual = true;
  FilterDesc? lastFilter;
  bool textureCached = false;
  bool sharedSnapshotComputed = false;
}

/// The replay result: ordered passes + totals.
class PassTimeline {
  PassTimeline({required this.passes, required this.profile});

  final List<ModelPass> passes;
  final CapabilityProfile profile;
  int flips = 0;

  /// Passes left open at endReplay (unbalanced op stream) — surfaces in the
  /// report meta like `pictureMismatch`.
  int unclosedPasses = 0;

  int get estimatedTrafficBytes =>
      passes.fold(0, (a, p) => a + p.estimatedTrafficBytes);

  /// Render passes only — blit-encoder ops excluded (they aren't GPU
  /// render passes and shouldn't inflate comparisons against captures).
  int get renderPassCount => passes.where((p) => !p.isBlit).length;

  Map<String, Object?> toJson() => {
    'profile': profile.name,
    'passCount': passes.length,
    'renderPassCount': renderPassCount,
    'flips': flips,
    'estimatedTrafficBytes': estimatedTrafficBytes,
    if (unclosedPasses > 0) 'unclosedPasses': unclosedPasses,
    'passes': passes.map((p) => p.toJson()).toList(),
  };
}

/// A Dart port of `impeller::Canvas`'s pass-structure decisions
/// (impeller/display_list/canvas.cc, 3.47.x).
///
/// Scope (see FEASIBILITY.md):
///  - All geometry is pre-transformed into root space, so the engine's
///    transform stack collapses to identity and coverage uses AABBs.
///  - Depth/stencil clip accounting is not modeled (clips only affect
///    coverage limits, matching clip_contents.cc bounding-box behavior).
///  - Filter subgraphs emit their documented pass counts (gaussian = 3),
///    not a full Contents::Render simulation.
class ImpellerCanvasReplay {
  ImpellerCanvasReplay({
    required this.profile,
    required this.screenSize,
    required this.rootHasBackdropFilter,
    required this.maxRootBlendMode,
  }) {
    // dl_dispatcher.cc:949: draw offscreen from the start when there's a
    // root backdrop filter or a root advanced blend without fbf.
    _requiresReadback =
        rootHasBackdropFilter ||
        (!profile.supportsFramebufferFetch &&
            isAdvancedBlend(maxRootBlendMode));
    final rootLabel = _requiresReadback
        ? 'EntityPass Root (offscreen)'
        : 'EntityPass Root';
    _passes.add(
      _Pass(
        size: screenSize,
        origin: ui.Offset.zero,
        isSubpass: false,
        label: rootLabel,
        reason: _requiresReadback ? 'root-readback' : 'root',
        writesToSurface: !_requiresReadback,
        msaa: profile.msaaSamples,
      ),
    );
    _clipCoverage = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
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

  bool get _skipping => _stack.last.skipping;

  Rect get _passRect => ui.Rect.fromLTWH(
    _passes.last.origin.dx,
    _passes.last.origin.dy,
    _passes.last.size.width,
    _passes.last.size.height,
  );

  /// Register one backdrop saveLayer op (dl_dispatcher.cc:998-1016). Every
  /// backdrop increments the total count; a non-null [backdropId]
  /// additionally registers per-id data. Must be called once per
  /// saveLayerBackdrop op, in order, BEFORE replay.
  void registerBackdrop(int? backdropId, FilterDesc filter) {
    _backdropCountRemaining++;
    if (backdropId == null) {
      return;
    }
    final existing = _backdropData[backdropId];
    if (existing == null) {
      _backdropData[backdropId] = _BackdropData()
        ..backdropCount = 1
        ..lastFilter = filter;
    } else {
      existing.backdropCount++;
      if (!existing.lastFilter!.isSameFilter(filter)) {
        existing.allFiltersEqual = false;
      }
      existing.lastFilter = filter;
    }
  }

  // ------------------------------------------------------------- primitives

  void save() {
    if (_skipping) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }
    _stack.add(_StackEntry());
    _clipStack.add(_clipCoverage);
  }

  /// `Canvas::SaveLayer` — canvas.cc:1710.
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

    // GetLocalCoverageLimit (canvas.cc:1673): parent pass texture ∩ clip ∩
    // render target bounds (canvas.cc:1707).
    final coverageLimit = _clipCoverage
        .intersect(_passRect)
        .intersect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height));
    if (coverageLimit.isEmpty) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }

    // Opacity peephole (canvas.cc:1728).
    if (canDistributeOpacity &&
        backdropFilter == null &&
        paint.canApplyOpacityPeephole &&
        !mayClipContents) {
      save();
      return;
    }

    final coverage = _computeSaveLayerCoverage(
      bounds,
      coverageLimit,
      paint.imageFilter,
      floodOutputCoverage: isBlendModeDestructive(paint.blendMode),
      // canvas.cc:1747: flood_input = backdrop || modifies-transparent-
      // black. Unbounded content is NOT here — dl_dispatcher.cc:321-326
      // keeps caller bounds; it only floods when no bounds were supplied
      // (coverage.IsMaximum below).
      floodInputCoverage:
          backdropFilter != null || paint.colorFilterAffectsTransparentBlack,
      ctmScale: ctmScale,
    );
    if (coverage == null || coverage.isEmpty) {
      _stack.add(_StackEntry(skipping: true));
      return;
    }

    // Subpass size: rounded out unless an image filter is present
    // (canvas.cc:1764-1785).
    final ui.Size subpassSize;
    if (paint.imageFilter != null) {
      subpassSize = ui.Size(
        coverage.width.truncateToDouble(),
        coverage.height.truncateToDouble(),
      );
    } else {
      final r = coverage;
      subpassSize = ui.Size(
        (r.right.ceil() - r.left.floor()).toDouble(),
        (r.bottom.ceil() - r.top.floor()).toDouble(),
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

    // ---------------- backdrop handling (canvas.cc:1798-1890) ---------------
    bool emitBackdropContentsInsideSubpass = false;
    if (backdropFilter != null) {
      var willCacheBackdrop = false;
      _BackdropData? data;
      var backdropCount = 1;
      if (backdropId != null) {
        data = _backdropData[backdropId];
        if (data != null) {
          willCacheBackdrop = data.backdropCount > 1;
          backdropCount = data.backdropCount;
        }
      }

      if (!willCacheBackdrop || !(data?.textureCached ?? false)) {
        _backdropCountRemaining -= backdropCount;
        // canvas.cc:1826-1830: flip to onscreen only for the LAST backdrop
        // filter, only with framebuffer fetch, only when only the root pass
        // is open.
        final shouldUseOnscreen =
            profile.supportsFramebufferFetch &&
            _backdropCountRemaining == 0 &&
            _passes.length == 1;
        _flipBackdrop(
          shouldUseOnscreen: shouldUseOnscreen,
        );
        if (willCacheBackdrop) {
          data?.textureCached = true;
        }
      }

      if (willCacheBackdrop && (data?.allFiltersEqual ?? false)) {
        // Shared snapshot path (canvas.cc:1857-1887): the filter runs ONCE
        // for the whole group; the entity is drawn into the PARENT pass and
        // no subpass is created for this member.
        if (data != null && !data.sharedSnapshotComputed) {
          // RenderToSnapshot(renderer_, {}, {}) gets NO coverage hint —
          // the shared snapshot covers the flipped input texture, i.e.
          // the pass coverage limit (canvas.cc:1857-1887).
          _emitFilterPasses(
            backdropFilter,
            coverageLimit,
            'shared backdrop',
            ctmScale: ctmScale,
          );
          data.sharedSnapshotComputed = true;
        }
        _passes.last.drawCount++;
        save();
        return;
      }
      emitBackdropContentsInsideSubpass = true;
    }

    // Push the subpass (canvas.cc:1900-1919).
    _emitPass(
      label: 'EntityPass Subpass',
      size: clamped,
      origin: coverage.topLeft,
      reason: debugLabel,
      isSubpass: true,
    );
    _saveLayerStates.add(_SaveLayerState(paint, coverage, ctmScale));
    _stack.add(_StackEntry(isSubpass: true));
    // PushSubpass: clip coverage becomes the subpass coverage (canvas.cc:1925).
    _clipStack.add(_clipCoverage);
    _clipCoverage = coverage;

    if (emitBackdropContentsInsideSubpass) {
      // The backdrop entity is the first thing drawn in the new subpass;
      // its filter contents spawn their own passes (canvas.cc:1934-1937).
      _emitFilterPasses(
        backdropFilter!,
        coverage,
        'backdrop filter',
        ctmScale: ctmScale,
      );
      _passes.last.drawCount++;
    }
  }

  void clip(Rect coverage, {bool isDifference = false}) {
    if (_skipping || isDifference) {
      // Difference clips don't shrink coverage (clip_contents.cc:45).
      return;
    }
    _clipCoverage = _clipCoverage.intersect(coverage);
  }

  /// A normal draw op reaching `AddRenderEntityToCurrentPass`. Only the
  /// blend mode matters for pass decisions.
  void draw({
    required ui.BlendMode blendMode,
    Rect? bounds,
    FilterDesc? imageFilter,
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    if (_skipping) {
      return;
    }
    // A draw-level Paint.imageFilter applies to the draw's contents —
    // the filtered draw renders via the filter's RenderToSnapshot passes
    // (gaussian_blur_filter_contents.cc) sized to the draw bounds and
    // scaled by the op's transform basis.
    if (imageFilter != null) {
      // drawPaint/drawPicture carry no bounds — the filter pass sizes to
      // the current clip/pass coverage (canvas.cc GetLocalCoverageLimit).
      final coverage = bounds ?? _clipCoverage;
      _emitFilterPasses(
        imageFilter,
        coverage,
        'drawFilter',
        ctmScale: ctmScale,
      );
    }
    // canvas.cc:2353: advanced blends.
    if (isAdvancedBlend(blendMode)) {
      if (profile.supportsFramebufferFetch) {
        _passes.last.drawCount++;
      } else {
        _flipBackdrop();
        // ColorFilterContents::MakeBlend renders via a snapshot subpass;
        // the engine sizes it by the entity's coverage hint intersected
        // with the clip (canvas.cc:2375-2379), not the whole pass.
        final cov = bounds?.intersect(_clipCoverage);
        _emitPass(
          label: 'advanced blend filter',
          size: cov == null || cov.isEmpty ? _passes.last.size : cov.size,
          origin: cov == null || cov.isEmpty
              ? _passes.last.origin
              : cov.topLeft,
          reason: 'blend:${blendMode.name}',
          isSubpass: true,
        );
        _popSubpassEntry();
        _passes.last.drawCount++;
      }
      return;
    }
    _passes.last.drawCount++;
  }

  /// `Canvas::Restore` — canvas.cc:1940.
  void restore() {
    if (_stack.length == 1) {
      return;
    }
    final entry = _stack.removeLast();
    if (entry.skipping) {
      return;
    }
    // Every non-skipping entry pushed one clip-coverage frame.
    _clipCoverage = _clipStack.removeLast();
    if (entry.isSubpass) {
      _popSubpassEntry();
      final state = _saveLayerStates.removeLast();

      // Image filters apply on restore via CreateContentsForSubpassTarget —
      // the filter render spawns its own passes before the entity draw.
      final filter = state.paint.imageFilter;
      if (filter != null) {
        _emitFilterPasses(
          filter,
          state.coverage,
          'saveLayer restore',
          ctmScale: state.ctmScale,
        );
      }

      if (isAdvancedBlend(state.paint.blendMode)) {
        if (!profile.supportsFramebufferFetch) {
          // canvas.cc:2029: flip the PARENT pass for the advanced blend.
          _flipBackdrop();
          _emitPass(
            label: 'advanced blend filter',
            // canvas.cc:2020: SetCoverageHint(element_entity.GetCoverage())
            // — the element is the restored saveLayer, sized to its
            // coverage, not the whole parent pass.
            size: state.coverage.size,
            origin: state.coverage.topLeft,
            reason: 'restore-blend:${state.paint.blendMode.name}',
            isSubpass: true,
          );
          _popSubpassEntry();
        }
      }
      _passes.last.drawCount++;
    }
  }

  /// `Canvas::EndReplay` — canvas.cc:2607.
  PassTimeline endReplay() {
    // Any still-open subpasses (unbalanced op stream) get finished here;
    // unclosedPasses surfaces them in the report like pictureMismatch.
    while (_passes.length > 1) {
      _unclosedPasses++;
      _finishPass(_passes.removeLast());
    }
    _finishPass(_passes.removeLast());
    if (_requiresReadback) {
      if (profile.supportsBlitToOnscreen) {
        _emitted.add(
          ModelPass(
            writesToSurface: true,
            isBlit: true,
            label: 'BlitToOnscreen (blit pass)',
            size: screenSize,
            reason: 'onscreen-blit',
          ),
        );
      } else {
        _emitted.add(
          ModelPass(
            writesToSurface: true,
            label: 'EntityPass Root Render Pass (onscreen)',
            size: screenSize,
            reason: 'onscreen-copy-pass',
          )..drawCount = 1,
        );
      }
    }
    // Resolve parent refs → emit indices (children emit before parents
    // finish, so indices only exist now).
    for (final p in _emitted) {
      final i = p._parentPass?.emitIndex ?? -1;
      p.parent = i >= 0 ? i : null;
    }
    return PassTimeline(passes: _emitted, profile: profile)
      ..flips = _flips
      ..unclosedPasses = _unclosedPasses;
  }

  // --------------------------------------------------------------- internals

  void _emitPass({
    required String label,
    required ui.Size size,
    required ui.Offset origin,
    required String reason,
    required bool isSubpass,
  }) {
    _passes.add(
      _Pass(
        size: size,
        origin: origin,
        isSubpass: isSubpass,
        label: label,
        reason: reason,
        parent: _passes.isEmpty ? null : _passes.last,
        // Blend/filter intermediate targets run msaa_enabled=false.
        msaa: label == 'advanced blend filter' ? 1 : profile.msaaSamples,
      ),
    );
  }

  void _finishPass(_Pass p) {
    p.emitIndex = _emitted.length;
    p.modelPass =
        ModelPass(
            label: p.label,
            size: p.size,
            reason: p.reason,
            writesToSurface: p.writesToSurface,
          )
          ..drawCount = p.drawCount
          ..msaaSamples = p.msaa
          .._parentPass = p.parent;
    _emitted.add(p.modelPass!);
  }

  /// Close the top pass (used by FlipBackdrop and subpass restore).
  void _popSubpassEntry() {
    final p = _passes.removeLast();
    _finishPass(p);
  }

  /// `Canvas::FlipBackdrop` — canvas.cc:2415.
  /// Ends the CURRENT pass (top of stack), restarts it, and draws the
  /// stored texture back in as the "MSAA backdrop" plus clip replays.
  void _flipBackdrop({bool shouldUseOnscreen = false}) {
    _flips++;
    final ended = _passes.removeLast();
    _finishPass(ended);

    if (shouldUseOnscreen) {
      // canvas.cc:2469: flipping to the onscreen target clears the readback.
      _requiresReadback = false;
      // The next pass renders straight to the real surface (canvas.cc:2459).
      _passes.add(
        _Pass(
          size: screenSize,
          origin: ui.Offset.zero,
          isSubpass: false,
          label: 'EntityPass Root (onscreen, post-flip)',
          reason: 'flip→onscreen',
          writesToSurface: true,
        ),
      );
    } else {
      // The pass is restarted on a fresh texture of the same size
      // (canvas.cc:2477: same EntityPassTarget / size).
      _passes.add(
        _Pass(
          size: ended.size,
          origin: ended.origin,
          isSubpass: ended.isSubpass,
          label: '${ended.label} (restarted)',
          msaa: ended.msaa,
          reason: 'flip-restart',
          parent: ended.parent,
        ),
      );
    }
    // The restarted pass begins with the MSAA-backdrop redraw.
    _passes.last.drawCount = 1;
  }

  /// `ComputeSaveLayerCoverage` — impeller/entity/save_layer_utils.cc.
  Rect? _computeSaveLayerCoverage(
    Rect? contentCoverage,
    Rect coverageLimit,
    FilterDesc? imageFilter, {
    required bool floodOutputCoverage,
    required bool floodInputCoverage,
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    var coverage = contentCoverage;
    if (floodInputCoverage) {
      coverage = null; // Rect::MakeMaximum()
    }
    if (imageFilter != null) {
      final sourceLimit = _filterSourceCoverage(
        imageFilter,
        coverageLimit,
        ctmScale: ctmScale,
      );
      if (sourceLimit == null) {
        return null;
      }
      if (floodOutputCoverage || coverage == null) {
        return sourceLimit;
      }
      final transformed = coverage;
      final intersected = transformed.intersect(sourceLimit);
      if (!intersected.isEmpty &&
          _sizeDifferenceUnderThreshold(
            transformed.size,
            intersected.size,
            0.3,
          )) {
        return transformed;
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
    // Round up to coverage_limit when nearly equal (save_layer_utils.cc
    // tail).
    // save_layer_utils.cc:122: |intersected − limit| / limit < 0.3 →
    // denominator is the coverage limit (the LARGER size).
    if (_sizeDifferenceUnderThreshold(
      intersected.size,
      coverageLimit.size,
      0.3,
    )) {
      return coverageLimit;
    }
    return intersected;
  }

  static bool _sizeDifferenceUnderThreshold(
    ui.Size a,
    ui.Size b,
    double threshold,
  ) {
    return ((a.width - b.width).abs() / b.width) < threshold &&
        ((a.height - b.height).abs() / b.height) < threshold;
  }

  /// `FilterContents::GetFilterSourceCoverage` for the modeled filters:
  /// what input region the filter needs to cover `outputLimit`.
  Rect? _filterSourceCoverage(
    FilterDesc filter,
    Rect outputLimit, {
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    switch (filter.kind) {
      case 'blur':
        // gaussian_blur_filter_contents.cc:781-787: the radii are computed
        // in FILTER space then scaled by the transform basis — ctmScale
        // multiplies the radius, not the sigma. (ImageFilter.blur's
        // bounds: is a sampling-space quad, NOT a coverage clamp — it is
        // recorded on FilterDesc but does not shrink source coverage.)
        final sx = math.min(scaleSigma(filter.sigmaX), kMaxSigma);
        final sy = math.min(scaleSigma(filter.sigmaY), kMaxSigma);
        final rx = calculateBlurRadius(sx) * ctmScale.width;
        final ry = calculateBlurRadius(sy) * ctmScale.height;
        return Rect.fromLTRB(
          outputLimit.left - rx,
          outputLimit.top - ry,
          outputLimit.right + rx,
          outputLimit.bottom + ry,
        );
      case 'matrix':
        return outputLimit;
      default:
        return outputLimit;
    }
  }

  /// Emit the standalone subpasses a filter's RenderToSnapshot produces.
  void _emitFilterPasses(
    FilterDesc filter,
    Rect coverage,
    String context, {
    ui.Size ctmScale = const ui.Size(1, 1),
  }) {
    for (final p in estimateFilterPasses(filter, coverage.size, ctmScale)) {
      _emitted.add(
        ModelPass(label: p.label, size: p.size, reason: context)
          ..drawCount = 1
          .._parentPass = _passes.isEmpty ? null : _passes.last,
      );
    }
  }
}
