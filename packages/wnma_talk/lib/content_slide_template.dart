import 'package:flutter/material.dart';

import 'package:wnma_talk/wnma_talk.dart';

class ContentSlideTemplate extends FlutterDeckSlideWidget {
  const ContentSlideTemplate({
    required this.title,
    this.mainContent,
    this.description,
    this.secondaryContent,
    super.key,
  });

  final Widget title;
  final Widget? mainContent;
  final Widget? description;
  final Widget? secondaryContent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(100),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyLarge.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            child: Row(
              spacing: 32,
              children: [
                Flexible(
                  flex: 3,
                  fit: FlexFit.tight,
                  child: Column(
                    spacing: 64,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: theme.textTheme.display.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          letterSpacing: -5,
                          height: 1,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: title,
                        ),
                      ),
                      if (mainContent case final c?)
                        Expanded(
                          child: c,
                        ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Column(
                    spacing: 64,
                    children: [
                      ?description,
                      if (secondaryContent case final c?)
                        Expanded(
                          child: c,
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
