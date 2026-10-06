import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impeeler/impeeler.dart';
import 'package:impeeler/src/engine/display_list.dart';
import 'package:impeeler/src/engine/ops.dart';

Widget dir(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// flutter_test's default view (800x600 logical @3), with the GPU decisions
/// of [profile].
GpuDevice testView(CapabilityProfile profile) => GpuDevice.custom(
  DeviceInfo.genericPhone(
    platform: TargetPlatform.iOS,
    id: 'test-view',
    name: 'flutter_test view',
    screenSize: const Size(800, 600),
    pixelRatio: 3,
  ),
  gpu: profile,
  name: profile.name,
);

FrameCapture captureNow() => ImpeelerBinding.instance.captureFrame()!;

PassTimeline timelineFor(FrameCapture capture, CapabilityProfile profile) =>
    estimateFrame(capture, testView(profile)).timeline;

/// Prints the passes per profile, for eyeballing a failing case.
void dump(String name, FrameCapture capture) {
  for (final profile in [
    CapabilityProfile.iosDevice,
    CapabilityProfile.androidVulkan,
    CapabilityProfile.androidVulkanNoFetch,
  ]) {
    final t = timelineFor(capture, profile);
    // ignore: avoid_print
    print(
      '$name / ${profile.name}: ${t.renderPassCount} render passes, '
      'flips=${t.flips}',
    );
    for (final p in t.passes) {
      // ignore: avoid_print
      print(
        '    ${p.engineLabel} ${p.size.width.round()}x'
        '${p.size.height.round()} ${p.role.name} ${p.cause ?? ''}',
      );
    }
  }
}

void main() {
  regressionTests();
  scopeTests();
  coverageTests();
  clipSaveLayerTests();
  clipBoundedTests();
  clipIntersectTests();

  testWidgets('backdrop blur sigma=10', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            Positioned(
              left: 100,
              top: 100,
              width: 200,
              height: 200,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    dump('backdrop_blur10', captureNow());
    expect(
      timelineFor(
        captureNow(),
        CapabilityProfile.iosDevice,
      ).passes.length,
      6,
    );
  });

  testWidgets('two sibling backdrop blurs', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            for (final dx in [100.0, 300.0])
              Positioned(
                left: dx,
                top: 100,
                width: 150,
                height: 150,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
    final c2 = captureNow();
    dump('two_backdrops', c2);
    expect(timelineFor(c2, CapabilityProfile.iosDevice).passes.length, 11);
  });

  testWidgets('two blurs in BackdropGroup', (tester) async {
    await tester.pumpWidget(
      dir(
        BackdropGroup(
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
              for (final dx in [100.0, 300.0])
                Positioned(
                  left: dx,
                  top: 100,
                  width: 150,
                  height: 150,
                  child: BackdropFilter.grouped(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final c3 = captureNow();
    dump('backdrop_group', c3);
    expect(timelineFor(c3, CapabilityProfile.iosDevice).passes.length, 5);
  });

  testWidgets('full-screen saturation blend', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            Positioned.fill(
              child: CustomPaint(
                painter: _BlendPainter(ui.BlendMode.saturation),
              ),
            ),
          ],
        ),
      ),
    );
    final c4 = captureNow();
    dump('saturation_blend', c4);
    // fbf: the root pass plus a snapshot of the blend's source (confirmed by
    // the saturation_blend validation scene on Metal); no-fbf: offscreen +
    // flip + AdvancedBlend(Src) snapshot + Advanced Blend Filter + copy
    // (five full-screen passes measured on the Pixel 10).
    expect(timelineFor(c4, CapabilityProfile.iosDevice).passes.length, 2);
    expect(
      timelineFor(c4, CapabilityProfile.androidVulkanNoFetch).passes.length,
      5,
    );
  });

  testWidgets('opacity over single child vs overlapping children', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Opacity(
          opacity: 0.5,
          child: ColoredBox(color: Color(0xFF224466)),
        ),
      ),
    );
    final c5 = captureNow();
    dump('opacity_single', c5);
    expect(timelineFor(c5, CapabilityProfile.iosDevice).passes.length, 1);

    await tester.pumpWidget(
      dir(
        const Opacity(
          opacity: 0.5,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
              Positioned.fill(child: ColoredBox(color: Color(0x80FF0000))),
            ],
          ),
        ),
      ),
    );
    final c6 = captureNow();
    dump('opacity_overlap', c6);
    expect(timelineFor(c6, CapabilityProfile.iosDevice).passes.length, 2);
  });

  testWidgets('two blurs inside tight clip', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            Positioned(
              left: 200,
              top: 150,
              width: 400,
              height: 300,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    for (final dx in [40.0, 200.0])
                      Positioned(
                        left: dx,
                        top: 50,
                        width: 150,
                        height: 150,
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final c7 = captureNow();
    dump('tight_clip_backdrops', c7);
    expect(timelineFor(c7, CapabilityProfile.iosDevice).passes.length, 11);
  });

  testWidgets('identity-matrix backdrop inside tight clip', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            Positioned(
              left: 200,
              top: 150,
              width: 400,
              height: 300,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                // The "backdrop barrier": an identity-transform BackdropFilter
                // wraps the blurs, so the inner flips end and restart the
                // barrier's clip-sized subpass instead of the full root pass.
                child: BackdropFilter(
                  filter: ui.ImageFilter.matrix(Matrix4.identity().storage),
                  child: Stack(
                    children: [
                      for (final dx in [40.0, 200.0])
                        Positioned(
                          left: dx,
                          top: 50,
                          width: 150,
                          height: 150,
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final c8 = captureNow();
    dump('identity_matrix_clip', c8);
    expect(timelineFor(c8, CapabilityProfile.iosDevice).passes.length, 14);
  });

  testWidgets('CupertinoNavigationBar + CupertinoTabBar', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('Title')),
          child: Column(
            children: [
              const Expanded(child: ColoredBox(color: Color(0xFF224466))),
              CupertinoTabBar(
                items: const [
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.house)),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.star)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final c9 = captureNow();
    dump('cupertino_bars', c9);
    expect(timelineFor(c9, CapabilityProfile.iosDevice).passes.length, 6);
  });

  testWidgets('Cupertino bars with opaque colors: no blurs', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Title'),
            backgroundColor: Color(0xFFF9F9F9),
          ),
          child: Column(
            children: [
              const Expanded(child: ColoredBox(color: Color(0xFF224466))),
              CupertinoTabBar(
                backgroundColor: const Color(0xFFF9F9F9),
                items: const [
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.house)),
                  BottomNavigationBarItem(icon: Icon(CupertinoIcons.star)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final c10 = captureNow();
    dump('cupertino_bars_opaque', c10);
    expect(timelineFor(c10, CapabilityProfile.iosDevice).passes.length, 1);
  });

  testWidgets('backdrop filter with color matrix', (tester) async {
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0, //
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    final c11 = captureNow();
    dump('backdrop_plus_matrix', c11);
    // The ColorFilterLayer folds into the backdrop's saveLayer paint —
    // kSaveLayerRenderFlags advertises kCallerCanApplyColorFilter — so
    // the engine emits ONE saveLayer, not a ColorFilter subpass + a
    // backdrop subpass.
    expect(timelineFor(c11, CapabilityProfile.iosDevice).passes.length, 6);
  });
}

class _BlendPainter extends CustomPainter {
  _BlendPainter(this.blendMode);
  final ui.BlendMode blendMode;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()
        ..color = const ui.Color(0xFF808080)
        ..blendMode = blendMode,
    );
  }

  @override
  bool shouldRepaint(_BlendPainter old) => false;
}

class _TranslatePainter extends CustomPainter {
  const _TranslatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Non-identity canvas transform: saveLayer bounds recorded in picture
    // space must be mapped to root space by the LAYER transform only —
    // re-applying the op's own ctm would double-translate.
    canvas.translate(10, 10);
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 50, 50), Paint());
    // Content required — the engine rewrites the op rect to accumulated
    // CONTENT bounds (dl_builder.cc:716), so an empty saveLayer resolves
    // to empty bounds.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..color = const Color(0xFF224466),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void regressionTests() {
  testWidgets('nested opacity peepholes (engine: inner saveLayer is a '
      'compatible op)', (tester) async {
    await tester.pumpWidget(
      dir(
        const Opacity(
          opacity: 0.5,
          child: Opacity(
            opacity: 0.5,
            child: ColoredBox(color: Color(0xFF224466)),
          ),
        ),
      ),
    );
    final capture = captureNow();
    dump('opacity_nested', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // The nested saveLayer op only contributes bounds to the outer group —
    // its internal overlap does not propagate (TransferLayerBounds,
    // dl_builder.cc:761). Both layers therefore peephole.
    expect(t.passes.length, 1);
  });

  testWidgets('opacity over two repaint boundaries: one saveLayer each', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Opacity(
          opacity: 0.5,
          child: Column(
            children: [
              RepaintBoundary(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ColoredBox(color: Color(0xFF224466)),
                ),
              ),
              RepaintBoundary(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ColoredBox(color: Color(0x80FF0000)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final capture = captureNow();
    dump('opacity_two_pictures', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // dl_dispatcher.cc:803-810: each drawDisplayList gets its own
    // saveLayer(alpha); each picture's group is compatible → both peephole.
    expect(t.passes.length, 1);
  });

  testWidgets('opacity over OVERLAPPING repaint boundaries → group wrap', (
    tester,
  ) async {
    // container_layer.cc:141-153: a child whose paint_bounds intersects
    // the preceding children's union zeroes the renderable flags → one
    // saveLayer(alpha) wraps the whole group.
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Opacity(
                opacity: 0.5,
                child: Stack(
                  children: [
                    // Sizes the stack (all-positioned children → 0x0).
                    SizedBox(width: 150, height: 150),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: RepaintBoundary(
                        child: ColoredBox(
                          color: Color(0xFF224466),
                          child: SizedBox(width: 100, height: 100),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 50,
                      child: RepaintBoundary(
                        child: ColoredBox(
                          color: Color(0xFF664422),
                          child: SizedBox(width: 100, height: 100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('opacity_overlap_pictures', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // Overlapping children → flags zeroed → ONE group saveLayer(alpha)
    // → subpass + root = 2 passes (vs 1 if each peepholed separately).
    expect(t.passes.length, 2);
    expect(
      t.passes.any(
        (p) =>
            p.role == PassRole.saveLayer &&
            (p.cause ?? '').toLowerCase().contains('opacity'),
      ),
      isTrue,
    );
  });

  testWidgets('opacity over text: glyph overlap poisons group compat', (
    tester,
  ) async {
    // drawParagraph → UpdateLayerOpacityCompatibility(false)
    // (dl_builder.cc:1855) — the alpha saveLayer must NOT peephole.
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Opacity(
                opacity: 0.5,
                child: Text('hello', textDirection: TextDirection.ltr),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('opacity_text', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    expect(t.passes.length, 2);
  });

  testWidgets('backdrop inside Opacity group does not readback root', (
    tester,
  ) async {
    // contains_backdrop_filter marks only the ENCLOSING scope
    // (dl_builder.cc:532, :719-721) — a backdrop nested inside an Opacity
    // group's saveLayer must not force a root readback pass.
    await tester.pumpWidget(
      dir(
        Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Opacity(
                opacity: 0.5,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    children: [
                      const RepaintBoundary(
                        child: ColoredBox(
                          color: Color(0xFF224466),
                          child: SizedBox(width: 100, height: 100),
                        ),
                      ),
                      Positioned(
                        left: 50,
                        top: 50,
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: const RepaintBoundary(
                            child: ColoredBox(
                              color: Color(0x22664422),
                              child: SizedBox(width: 100, height: 100),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('backdrop_inside_opacity', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    expect(t.passes.any((p) => p.role == PassRole.offscreenRoot), isFalse);
    expect(
      t.passes.any(
        (p) =>
            p.role == PassRole.copyToOnscreen ||
            p.role == PassRole.blitToOnscreen,
      ),
      isFalse,
    );
  });

  testWidgets('custom paint canvas translate: no double CTM', (tester) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned(
              left: 20,
              top: 30,
              child: CustomPaint(
                size: Size(200, 200),
                painter: _TranslatePainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    final synth = LayerSynthesizer();
    final frameOps = synth.synthesize(capture.root, capture.physicalSize);
    // Painter: canvas.translate(10,10) then saveLayer(0,0,50,50) → in the
    // canvas's picture space that's (10,10,60,60); the CustomPaint sits at
    // (20,30) logical → root-space bounds ≈ (20+10, 30+10)×3 …(70×3, 90×3).
    // With the double-CTM bug it would land ~(30,60)×3 or further.
    final sl = frameOps.ops.whereType<MSaveLayer>().first;
    expect(sl.bounds!.left, closeTo(90, 40)); // (20+10)*3 with tolerances
    expect(sl.bounds!.top, closeTo(120, 40)); // (30+10)*3
    expect(sl.bounds!.width, closeTo(150, 60));
  });
}

class _UnboundedSaveLayerPainter extends CustomPainter {
  const _UnboundedSaveLayerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer over unbounded content (drawPaint): content_is_unbounded
    // kills can_distribute_opacity — the peephole must NOT fire.
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..color = const Color(0x80000000),
    );
    canvas.drawPaint(Paint()..color = const Color(0xFF224466));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SaveLayerBlendPainter extends CustomPainter {
  const _SaveLayerBlendPainter({this.blendInside = false});
  final bool blendInside;

  @override
  void paint(Canvas canvas, Size size) {
    if (blendInside) {
      // Advanced blend INSIDE the saveLayer contents: composites against
      // the subpass texture — does NOT count toward max_root_blend_mode.
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 50, 50),
        Paint()..color = const Color(0x80FF0000),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 50, 50),
        Paint()
          ..color = const Color(0xFF224466)
          ..blendMode = BlendMode.saturation,
      );
      canvas.restore();
      return;
    }
    // An advanced blend mode on the saveLayer PAINT: the restore composites
    // the subpass texture with `saturation` against the parent pass — the
    // composite IS a root-scope blend op → max_root_blend_mode → readback
    // on no-FBF (dl_dispatcher.cc:942-951).
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..blendMode = BlendMode.saturation,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..color = const Color(0xFF224466),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SaveLayerBlendPainter oldDelegate) =>
      oldDelegate.blendInside != blendInside;
}

void scopeTests() {
  testWidgets('canvas.saveLayer with unbounded content does not peephole', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _UnboundedSaveLayerPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('saveLayer_unbounded', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // drawPaint inside the saveLayer → content unbounded → no peephole →
    // one real subpass + root.
    expect(t.passes.length, 2);
    expect(
      t.passes.any((p) => p.role == PassRole.saveLayer),
      isTrue,
    );
  });

  testWidgets('saveLayer with advanced blend: flip on restore, '
      'no root readback', (tester) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _SaveLayerBlendPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('saveLayer_blend', capture);
    final noFetch = timelineFor(
      capture,
      CapabilityProfile.androidVulkanNoFetch,
    );
    final fetch = timelineFor(capture, CapabilityProfile.iosDevice);
    // The composite blend is a root-scope op → root goes offscreen on
    // no-FBF, stays onscreen on FBF (framebuffer-fetch blend in-pass).
    expect(
      noFetch.passes.any((p) => p.role == PassRole.offscreenRoot),
      isTrue,
    );
    expect(fetch.passes.first.role, isNot(PassRole.offscreenRoot));
    expect(
      fetch.passes.where((p) => p.role == PassRole.saveLayer).length,
      1,
    );

    // The same blend INSIDE a saveLayer's contents never leaves the subpass:
    // root must stay onscreen even without FBF.
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _SaveLayerBlendPainter(blendInside: true),
              ),
            ),
          ],
        ),
      ),
    );
    final capture2 = captureNow();
    dump('saveLayer_blend_inside', capture2);
    final noFetch2 = timelineFor(
      capture2,
      CapabilityProfile.androidVulkanNoFetch,
    );
    expect(
      noFetch2.passes.any((p) => p.role == PassRole.offscreenRoot),
      isFalse,
    );
  });
}

class _NullBoundsSaveLayerPainter extends CustomPainter {
  const _NullBoundsSaveLayerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer(null) — no caller bounds — resolves coverage from the
    // accumulated CONTENT bounds (dl_builder.cc:717), not the clip.
    // The multiply paint prevents the opacity peephole so a real subpass
    // is created.
    canvas.saveLayer(null, Paint()..blendMode = BlendMode.multiply);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..color = const Color(0xFF224466),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DrawFilterPainter extends CustomPainter {
  const _DrawFilterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Draw-level Paint.imageFilter — the filtered draw renders via the
    // filter's RenderToSnapshot passes, sized to the draw bounds.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()
        ..color = const Color(0xFF224466)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void coverageTests() {
  testWidgets('canvas.saveLayer(null) resolves to content bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _NullBoundsSaveLayerPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('saveLayer_null_bounds', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // saveLayer over bounded content — no caller bounds, so coverage =
    // content bounds (150x150 at DPR 3), NOT the 2400x1800 clip limit.
    final sub = t.passes.firstWhere(
      (p) => (p.cause ?? '').startsWith('canvas.saveLayer'),
    );
    expect(sub.size.width, lessThan(200));
    expect(sub.size.height, lessThan(200));
  });

  testWidgets('draw-level Paint.imageFilter produces blur passes', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _DrawFilterPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('draw_image_filter', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // Blur draws spawn downsample + Y + X passes plus the root.
    expect(
      t.passes
          .where((p) => p.engineLabel == EngineLabels.gaussianBlurFilter)
          .length,
      3,
    );
    expect(t.passes.length, greaterThan(3));
  });
}

void clipSaveLayerTests() {
  testWidgets('antiAliasWithSaveLayer clip wraps children in a saveLayer', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: ClipRRect(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                borderRadius: BorderRadius.all(Radius.circular(12)),
                // RepaintBoundary forces needsCompositing so the clip
                // produces an actual ClipRRectLayer (otherwise the
                // framework clips the context directly — no layer).
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: ColoredBox(color: Color(0xFF224466)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('aa_clip_savelayer', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // clip_shape_layer.h:104: ApplyClip → saveLayer(paint_bounds) →
    // children. Content is a single compatible picture → the saveLayer
    // peepholes (canvas.cc:1728): ONE root pass, children drawn in it.
    // The subtree must NOT vanish — verify draw count in root.
    expect(t.passes.length, 1);
    expect(t.passes.first.drawCount, greaterThanOrEqualTo(2));
    // An opaque-content variant would create a subpass; assert the clip
    // subtree produced a recorded picture at all (positional join worked).
    expect(capture.missingPictures, 0);
  });
}

class _ClippedDrawPaintPainter extends CustomPainter {
  const _ClippedDrawPaintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // clipRect + drawPaint inside saveLayer — the clip makes the unbounded
    // op bounded (AccumulateUnbounded honors has_valid_clip,
    // dl_builder.cc:1949-1965) → the alpha saveLayer should peephole.
    canvas.saveLayer(
      null,
      Paint()..color = const Color(0x80FF0000),
    );
    canvas.clipRect(const Rect.fromLTWH(0, 0, 50, 50));
    canvas.drawPaint(Paint()..color = const Color(0xFF224466));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void clipBoundedTests() {
  testWidgets('clipRect + drawPaint inside saveLayer stays clip-bounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _ClippedDrawPaintPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('saveLayer_clipped_paint', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // With has_valid_clip the drawPaint contributes clip bounds → bounded,
    // group-compatible → peephole → 1 pass (root only).
    expect(t.passes.length, 1);
  });
}

class _NestedClipPainter extends CustomPainter {
  const _NestedClipPainter({this.difference = false});
  final bool difference;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      null,
      Paint()..color = const Color(0x80FF0000),
    );
    canvas.clipRect(const Rect.fromLTWH(0, 0, 80, 80));
    canvas.clipRect(
      const Rect.fromLTWH(10, 10, 60, 60),
      clipOp: difference ? ui.ClipOp.difference : ui.ClipOp.intersect,
    );
    canvas.drawPaint(Paint()..color = const Color(0xFF224466));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void clipIntersectTests() {
  testWidgets('nested intersect clips + drawPaint: bounded → peephole', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _NestedClipPainter(),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('nested_clip_paint', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // Both intersect clips → has_valid_clip → bounded → peephole.
    expect(t.passes.length, 1);
  });

  testWidgets('difference clip does not bound drawPaint → no peephole', (
    tester,
  ) async {
    await tester.pumpWidget(
      dir(
        const Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Color(0xFF111111)),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: CustomPaint(
                size: Size(100, 100),
                painter: _NestedClipPainter(difference: true),
              ),
            ),
          ],
        ),
      ),
    );
    final capture = captureNow();
    dump('diff_clip_paint', capture);
    final t = timelineFor(capture, CapabilityProfile.iosDevice);
    // intersect(0,0,80,80) then difference(10,10,60,60): difference doesn't
    // shrink the coverage bound → bound stays the outer clip → still
    // clip-bounded → peephole fires (the saveLayer alpha distributes).
    expect(t.passes.length, 1);
  });
}
