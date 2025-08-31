import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';

import 'package:wnma_talk/wnma_talk.dart';

class BigQuoteTemplate extends FlutterDeckSlideWidget {
  const BigQuoteTemplate({
    required this.title,
    this.subtitle,
    this.footer,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.primaryContainer,
        child: SlideNumber(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(100),
                child: Align(
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.title.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      letterSpacing: -5,
                      fontSize: 160,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: title,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
