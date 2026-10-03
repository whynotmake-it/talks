import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The slide number shown before the current frame, so a slide can tell
/// whether it was reached forward or backward along the deck.
int? _lastShownSlide;

/// Places the render stack on a slide and steps through [script] with deck
/// navigation, one [RenderStackStep] per step.
///
/// The concepts build up on this one visualization over the talk, so several
/// slides can use it with different scripts.
class RenderStackSlide extends FlutterDeckSlideWidget {
  RenderStackSlide({
    required String route,
    required String title,
    required this.script,
    this.entry,
    this.backEntry,
    FlutterDeckTransition? transition,
    String speakerNotes = '',
    super.key,
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           route: route,
           title: title,
           steps: script.length,
           speakerNotes: speakerNotes,
           transition: transition,
         ),
       );

  final List<RenderStackStep> script;

  /// The view the stack animates from when this slide is reached forward
  /// from the slide right before it — a cross-slide continuation.
  final RenderStackView? entry;

  /// The view the stack animates from when reached backward from the slide
  /// right after it.
  final RenderStackView? backEntry;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideFrame(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            final current = script[(step - 1).clamp(0, script.length - 1)];
            final p = Palette.of(context);
            final deck = FlutterDeck.of(context);
            final slideNumber = deck.slideNumber;
            // Written after the frame from the live deck, so outgoing slides
            // rebuilding in the same frame can't leave a stale number.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _lastShownSlide = deck.slideNumber;
            });
            final initialView = switch (slideNumber -
                (_lastShownSlide ?? slideNumber)) {
              1 => entry,
              -1 => backEntry,
              _ => null,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: Text(
                    current.caption,
                    maxLines: 1,
                    style: archivo(
                      48,
                      weight: 500,
                      height: 1.25,
                      color: p.text,
                    ),
                  ),
                ),
                Expanded(
                  child: RenderStack(
                    view: current.view,
                    initialView: initialView,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
