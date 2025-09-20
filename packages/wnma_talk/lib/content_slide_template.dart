import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';

import 'package:wnma_talk/wnma_talk.dart';

class ContentSlideTemplate extends FlutterDeckSlideWidget {
  const ContentSlideTemplate({
    this.title,
    this.mainContent,
    this.description,
    this.secondaryContent,
    this.insetSecondaryContent = false,
    this.fitSecondaryContent = false,
    super.key,
  });

  final Widget? title;
  final Widget? mainContent;
  final Widget? description;
  final Widget? secondaryContent;

  final bool insetSecondaryContent;
  final bool fitSecondaryContent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;
    final titleStyle = theme.textTheme.display.copyWith(
      color: colorScheme.onPrimaryContainer,
      letterSpacing: -5,
      height: 1,
    );
    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: SlideNumber(
          child: Padding(
            padding: const EdgeInsets.all(100),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              child: Column(
                spacing: 64,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title case final title? when insetSecondaryContent)
                    DefaultTextStyle.merge(
                      style: titleStyle,
                      child: title,
                    ),
                  Expanded(
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
                              if (title case final title?
                                  when !insetSecondaryContent)
                                DefaultTextStyle.merge(
                                  style: titleStyle,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1000,
                                    ),
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
                        if (description != null || secondaryContent != null)
                          Flexible(
                            flex: fitSecondaryContent ? 0 : 2,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
