import 'package:flutter/material.dart';

import 'package:wnma_talk/wnma_talk.dart';

class SingleContentSlideTemplate extends FlutterDeckSlideWidget {
  const SingleContentSlideTemplate({
    required this.title,
    this.mainContent,
    super.key,
  });

  final Widget title;
  final Widget? mainContent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyLarge.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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
        ),
      ),
    );
  }
}