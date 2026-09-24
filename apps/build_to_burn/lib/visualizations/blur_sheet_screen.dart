import 'dart:ui';

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/blinking_caret.dart';
import 'package:build_to_burn/visualizations/blur_scenario.dart';
import 'package:example_design/example_design.dart' show ExampleTheme;
import 'package:flutter/material.dart';

/// A phone screen from the hook: a busy list with a search sheet on top. The
/// sheet is a real `BackdropFilter` blur when [blur] is true, and its field
/// has a caret ticking in [caret] mode.
///
/// [caretOverlay] is laid over the caret and [screenOverlay] over the whole
/// screen, e.g. to highlight what repaints and what rasterizes. The widget
/// scales to its box, keeping [designSize]'s aspect ratio.
class BlurSheetScreen extends StatelessWidget {
  const BlurSheetScreen({
    required this.blur,
    required this.caret,
    this.caretOverlay,
    this.screenOverlay,
    super.key,
  });

  final bool blur;
  final CaretMode caret;
  final Widget? caretOverlay;
  final Widget? screenOverlay;

  static const designSize = Size(300, 640);

  static const _sheetTop = 250.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FittedBox(
      child: SizedBox.fromSize(
        size: designSize,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: p.text, width: 6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _Feed(),
                Positioned(
                  left: 0,
                  right: 0,
                  top: _sheetTop,
                  bottom: 0,
                  child: _SearchSheet(
                    blur: blur,
                    caret: caret,
                    caretOverlay: caretOverlay,
                  ),
                ),
                ?screenOverlay,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app underneath the sheet: colorful enough that the blur shows.
class _Feed extends StatelessWidget {
  const _Feed();

  static const _avatars = [
    ExampleTheme.signalBlue,
    ExampleTheme.marigold,
    ExampleTheme.roseQuartz,
    Color(0xFF3D63DD),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ColoredBox(
      color: p.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 54, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks', style: archivo(30, weight: 600, color: p.text)),
            const SizedBox(height: 18),
            for (var i = 0; i < 9; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _avatars[i % _avatars.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: .9 - (i % 3) * .15,
                            child: Container(height: 12, color: p.text),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: .6 + (i % 2) * .2,
                            child: Container(
                              height: 10,
                              color: p.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchSheet extends StatelessWidget {
  const _SearchSheet({
    required this.blur,
    required this.caret,
    required this.caretOverlay,
  });

  final bool blur;
  final CaretMode caret;
  final Widget? caretOverlay;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        enabled: blur,
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: blur ? p.surface.withValues(alpha: .5) : p.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              children: [
                Container(width: 44, height: 5, color: p.borderStrong),
                const SizedBox(height: 21),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: .7),
                    border: Border.all(
                      color: caret == CaretMode.none ? p.border : p.accent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 24, color: p.textTertiary),
                      const SizedBox(width: 10),
                      Text(
                        'Search',
                        style: archivo(18, color: p.textTertiary),
                      ),
                      const SizedBox(width: 2),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          BlinkingCaret(mode: caret, height: 26, width: 2.5),
                          if (caretOverlay case final overlay?)
                            Positioned(
                              left: -12,
                              top: -6,
                              width: 26.5,
                              height: 38,
                              child: overlay,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(width: 22, height: 22, color: p.control),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: .8 - i * .12,
                            child: Container(height: 10, color: p.control),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
