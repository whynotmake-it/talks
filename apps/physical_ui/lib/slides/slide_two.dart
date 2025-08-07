import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/wnma_talk.dart';

class SlideTwo extends FlutterDeckSlideWidget {
  const SlideTwo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlide.custom(
      builder: (context) => Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: DragDismissable.custom(
              onDismiss: () => FlutterDeck.of(context).next(),
              motion: CupertinoMotion.bouncy(),
              child: Heroine(
                tag: true,
                motion: CupertinoMotion.bouncy(),
                child: SizedBox.square(
                  dimension: 400,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: CircleBorder(),
                      color: theme.colorScheme.errorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(64),
              child: Text(
                'Physical UI',
                textHeightBehavior: TextHeightBehavior(
                  applyHeightToLastDescent: false,
                ),
                style:
                    FlutterDeckTheme.of(
                      context,
                    ).textTheme.title.copyWith(
                      color: theme.colorScheme.error,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
