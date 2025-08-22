import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlideTemplate extends FlutterDeckSlideWidget {
  const TitleSlideTemplate({
    required this.title,
    this.footer,
    super.key,
  });

  final Widget title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomRight,
            radius: 3,
            colors: [
              colorScheme.primary,
              colorScheme.primaryFixedDim,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return RadialGradient(
                    center: Alignment.bottomRight,
                    radius: 1,
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0),
                    ],
                  ).createShader(bounds);
                },
                child: GridPaper(
                  interval: 300,
                  color: colorScheme.primaryFixedDim,
                  divisions: 1,
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: 100,
              width: 1200,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.title.copyWith(
                  color: colorScheme.onPrimary,
                ),
                child: title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
