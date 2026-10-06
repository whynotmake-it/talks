// drop-in replacement for MaterialNotesFlatSlide.dart (single file)

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

// -------- State --------
final notesProvider = StateNotifierProvider<_NotesController, List<String>>((
  ref,
) {
  return _NotesController([
    'Window measurements',
    'Groceries',
    'Birthday ideas',
    'Trip packing list',
  ]);
});

class _NotesController extends StateNotifier<List<String>> {
  _NotesController(super.initial);
  void add(String t) => state = [t, ...state];
  void removeAt(int i) {
    if (i >= 0 && i < state.length) state = [...state]..removeAt(i);
  }
}

// -------- Slide (2 steps: 1 windows → 2 iOS) --------
class FlatTransitionSlide extends FlutterDeckSlideWidget {
  const FlatTransitionSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/material-notes',
          steps: 2, // 1: show Windows, 2: show iOS
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, step) => _FlatGallery(step: step),
      ),
    );
  }
}

// -------- Before/After gallery overlay --------
class _FlatGallery extends StatelessWidget {
  const _FlatGallery({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final showWin = step >= 1;
    final showIOS = step >= 2;
    return Stack(
      children: [
        AnimatedOpacity(
          duration: kThemeAnimationDuration,
          opacity: showWin ? 1 : 0,
          child: SizedBox.expand(
            child: ColoredBox(
              color: FlutterDeckTheme.of(
                context,
              ).materialTheme.scaffoldBackgroundColor,
            ),
          ),
        ),
        SizedBox.expand(
          child: Padding(
            padding: EdgeInsetsGeometry.all(32),
            child: _PairRow(
              visible: showWin,
              left: 'assets/history/windows7.webp',
              right: 'assets/history/windows8.jpg',
              leftFrom: const Offset(-1200, -40),
              rightFrom: const Offset(1200, -40),
            ),
          ),
        ),
        const SizedBox(height: 64),
        Positioned.fill(
          child: Stack(
            children: [
              AnimatedOpacity(
                opacity: showIOS ? 1 : 0,
                duration: kThemeAnimationDuration,
                child: SizedBox.expand(
                  child: ColoredBox(
                    color: FlutterDeckTheme.of(
                      context,
                    ).materialTheme.scaffoldBackgroundColor,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.all(32),
                  child: Row(
                    spacing: 32,
                    children: [
                      Expanded(
                        child: _PairRow(
                          visible: showIOS,
                          left: 'assets/history/ios6_home.png',
                          right: 'assets/history/ios7_home.png',
                          leftFrom: const Offset(0, -1200),
                          rightFrom: const Offset(0, -1200),
                          stagger: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PairRow(
                          visible: showIOS,
                          left: 'assets/history/ios6_calc.png',
                          right: 'assets/history/ios7_calc.png',
                          leftFrom: const Offset(0, -1200),
                          rightFrom: const Offset(0, -1200),
                          stagger: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.visible,

    required this.left,
    required this.right,
    this.leftFrom = const Offset(-800, 0),
    this.rightFrom = const Offset(800, 0),
    this.stagger = 0,
  });
  final bool visible;

  final String left;
  final String right;
  final Offset leftFrom;
  final Offset rightFrom;
  final int stagger;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 520) +
          Duration(milliseconds: 80 * stagger),
    );
    return Row(
      children: [
        Expanded(
          child: _FlyInCard(
            asset: left,
            from: visible ? Offset.zero : leftFrom,
            rotFrom: visible ? 0 : -.06,
            motion: motion,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FlyInCard(
            asset: right,
            from: visible ? Offset.zero : rightFrom,
            rotFrom: visible ? 0 : .06,
            motion: motion,
          ),
        ),
      ],
    );
  }
}

class _FlyInCard extends StatelessWidget {
  const _FlyInCard({
    required this.asset,
    required this.from,
    required this.rotFrom,
    required this.motion,
  });
  final String asset;
  final Offset from;
  final double rotFrom;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder<Offset>(
      value: from,
      motion: motion,
      converter: OffsetMotionConverter(),
      builder: (_, off, child) => Transform.translate(
        offset: off,
        child: SingleMotionBuilder(
          value: rotFrom,
          motion: motion,
          builder: (_, a, child) => Transform.rotate(angle: a, child: child),
          child: child,
        ),
      ),
      child: Material(
        elevation: 10,
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}
