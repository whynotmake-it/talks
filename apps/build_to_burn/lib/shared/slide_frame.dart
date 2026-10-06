import 'package:build_to_burn/shared/flow_notes.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The chrome every slide shares: the canvas, a top bar with the speaker dot,
/// and the slide number.
///
/// The speaker comes from the first line of the slide's speaker notes, using
/// wnma_talk's [timSlideNotesHeader] and [jesperSlideNotesHeader] convention.
class SlideFrame extends StatelessWidget {
  const SlideFrame({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(120, 0, 120, 96),
    super.key,
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final deck = FlutterDeck.of(context);
    final current = deck.slideNumber;
    final slide = _slideConfiguration(context) ?? deck.configuration;
    final speaker = switch (slide.speakerNotes.split('\n').first.trim()) {
      timSlideNotesHeader => SlideSpeaker.tim,
      jesperSlideNotesHeader => SlideSpeaker.jesper,
      _ => null,
    };
    return ColoredBox(
      color: p.canvas,
      child: Stack(
        children: [
          Positioned.fill(child: _frame(p, speaker, current)),
          Positioned.fill(
            child: FlowNoteOverlay(route: slide.route),
          ),
        ],
      ),
    );
  }

  /// This slide's own configuration, from the slide widget above it.
  ///
  /// `FlutterDeck.of(context).configuration` is the deck's current slide,
  /// and slides aren't rebuilt when it changes, so it can be another
  /// slide's.
  static FlutterDeckSlideConfiguration? _slideConfiguration(
    BuildContext context,
  ) {
    FlutterDeckSlideConfiguration? found;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is FlutterDeckSlideWidget && widget.configuration != null) {
        found = widget.configuration;
        return false;
      }
      return true;
    });
    return found;
  }

  Widget _frame(Palette p, SlideSpeaker? speaker, int current) {
    return DefaultTextStyle(
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
                  const Spacer(),
                  if (speaker case final speaker?) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: speaker.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
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
                    current.toString().padLeft(2, '0'),
                    style: p.eyebrow,
                  ),
                ],
              ),
            ),
          ),
        ],
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
