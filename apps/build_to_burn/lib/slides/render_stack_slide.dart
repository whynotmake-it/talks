import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// Places the render stack on a slide and steps through [script] with deck
/// navigation, one [RenderStackStep] per step.
///
/// The concepts build up on this one visualization over the talk, so several
/// slides can use it with different scripts.
class RenderStackSlide extends FlutterDeckSlideWidget {
  RenderStackSlide({
    required String route,
    required String title,
    required this.section,
    required this.script,
    String speakerNotes = '',
    super.key,
  }) : super(
         configuration: FlutterDeckSlideConfiguration(
           route: route,
           title: title,
           steps: script.length,
           speakerNotes: speakerNotes,
         ),
       );

  /// The agenda section, shown in the top bar.
  final String section;

  final List<RenderStackStep> script;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideFrame(
        label: 'Section $section',
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            final current = script[(step - 1).clamp(0, script.length - 1)];
            return RenderStack(view: current.view, caption: current.caption);
          },
        ),
      ),
    );
  }
}
