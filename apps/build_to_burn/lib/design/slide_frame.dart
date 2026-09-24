import 'package:build_to_burn/design/style.dart';
import 'package:example_design/example_design.dart' show LogoGlyph;
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The chrome every slide shares: the canvas, a top bar with the section
/// label and a progress strip, and the slide number.
class SlideFrame extends StatelessWidget {
  const SlideFrame({
    required this.child,
    this.label,
    this.padding = const EdgeInsets.fromLTRB(120, 0, 120, 96),
    super.key,
  });

  /// The eyebrow in the top bar, e.g. `02 · FRAME PIPELINE`.
  final String? label;

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final deck = FlutterDeck.of(context);
    final count = deck.router.slides.length;
    final current = deck.slideNumber;
    return ColoredBox(
      color: p.canvas,
      child: DefaultTextStyle(
        style: p.body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 120),
                child: Row(
                  children: [
                    LogoGlyph(color: p.accent, size: 36),
                    const SizedBox(width: 24),
                    if (label case final label?)
                      Text(label.toUpperCase(), style: p.eyebrow),
                    const Spacer(),
                    for (var i = 1; i <= count; i++)
                      Container(
                        width: 28,
                        height: 4,
                        margin: const EdgeInsets.only(left: 6),
                        color: i == current ? p.accent : p.control,
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 120),
                child: Row(
                  children: [
                    Text('whynotmake.it · Fluttercon 2026', style: p.caption),
                    const Spacer(),
                    Text(
                      '${current.toString().padLeft(2, '0')} / '
                      '${count.toString().padLeft(2, '0')}',
                      style: p.eyebrow,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recessed, bordered area for a demo or visualization.
class Stage extends StatelessWidget {
  const Stage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.inset,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
