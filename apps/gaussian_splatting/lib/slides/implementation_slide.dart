import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ImplementationSlide extends FlutterDeckSlideWidget {
  const ImplementationSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/implementation',
          steps: 3,
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return ContentSlideTemplate(
      title: const Text(
        'How is it implemented?',
        textAlign: TextAlign.left,
      ),
      secondaryContent: Image.asset(
        'assets/angle_project.png',
        fit: BoxFit.fitWidth,
      ),
      mainContent: FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => ColoredBox(
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column - Flutter limitations
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedElement(
                              visible: stepNumber >= 2,
                              stagger: 1,
                              child: _SectionTitle(
                                'Why not "pure" Flutter?',
                                theme: theme,
                                colorScheme: colorScheme,
                                color: colorScheme.error,
                              ),
                            ),

                            const SizedBox(height: 24),

                            AnimatedElement(
                              visible: stepNumber >= 2,
                              stagger: 2,
                              child: _LimitationsList(
                                theme: theme,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 48),

                      // Right column - ANGLE solution
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedElement(
                              visible: stepNumber >= 3,
                              stagger: 3,
                              child: _SectionTitle(
                                'ANGLE is a great fit',
                                theme: theme,
                                colorScheme: colorScheme,
                                color: colorScheme.primary,
                              ),
                            ),

                            const SizedBox(height: 24),

                            AnimatedElement(
                              visible: stepNumber >= 3,
                              stagger: 4,
                              child: _AngleBenefits(
                                theme: theme,
                                colorScheme: colorScheme,
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
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
    this.text, {
    required this.theme,
    required this.colorScheme,
    required this.color,
  });

  final String text;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.header.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _LimitationsList extends StatelessWidget {
  const _LimitationsList({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LimitationItem(
          icon: Icons.block,
          title: 'No 3D',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),
        _LimitationItem(
          icon: Icons.warning,
          title: 'No direct access to the GPU',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
        // const SizedBox(height: 20),
        // _LimitationItem(
        //   icon: Icons.speed,
        //   title: 'CPU bound',
        //   description: '',
        //   theme: theme,
        //   colorScheme: colorScheme,
        // ),
        // const SizedBox(height: 20),
        // _LimitationItem(
        //   icon: Icons.layers,
        //   title: 'No depth',
        //   description: '',
        //   theme: theme,
        //   colorScheme: colorScheme,
        // ),
      ],
    );
  }
}

class _LimitationItem extends StatelessWidget {
  const _LimitationItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: colorScheme.error,
          size: 56,
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyLarge.copyWith(
              color: colorScheme.onSurface,

              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AngleBenefits extends StatelessWidget {
  const _AngleBenefits({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BenefitItem(
          icon: Icons.computer,
          title: 'Portable',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),
        _BenefitItem(
          icon: Icons.verified,
          title: 'Well tested',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),
        _BenefitItem(
          icon: Icons.settings,
          title: 'Full GL',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),
        _BenefitItem(
          icon: Icons.integration_instructions,
          title: 'Existing package!',
          description: '',
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String description;
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
