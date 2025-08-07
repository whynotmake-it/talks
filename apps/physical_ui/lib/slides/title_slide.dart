import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: theme.colorScheme.primaryContainer,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Center(
              child: DragDismissable.custom(
                onDismiss: () => FlutterDeck.of(context).next(),
                motion: CupertinoMotion.bouncy(),
                child: Heroine(
                  tag: true,
                  motion: CupertinoMotion.bouncy(),
                  child: SizedBox.square(
                    dimension: 700,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: CircleBorder(),
                        color: theme.colorScheme.tertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'Physical UI',
                textHeightBehavior: TextHeightBehavior(
                  applyHeightToLastDescent: false,
                ),
                style:
                    FlutterDeckTheme.of(
                      context,
                    ).textTheme.display.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
