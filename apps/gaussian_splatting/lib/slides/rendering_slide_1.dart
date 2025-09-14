import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide1 extends FlutterDeckSlideWidget {
  const RenderingSlide1({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-1',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return ContentSlideTemplate(
      title: const Text(
        'Journey of a gaussian - file to screen',
        textAlign: TextAlign.left,
      ),
      secondaryContent: Highcode
      mainContent: FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => ColoredBox(
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepItem(
                  icon: Icons.text_fields_outlined,
                  title: 'From file to GPU',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StepItem extends StatelessWidget {
  const StepItem({
    required this.icon,
    required this.title,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: colorScheme.primary,
          size: 56,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyLarge.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
