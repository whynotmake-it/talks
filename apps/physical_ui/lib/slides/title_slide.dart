import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:heroine/heroine.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HookBuilder(
      builder: (context) {
        final animationController = useAnimationController(
          duration: Durations.extralong4,
        );

        useEffect(() {
          animationController.repeat(reverse: true);
          return null;
        }, [animationController]);

        final thickness = useAnimation(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeInOutSine,
          ),
        );

        return FlutterDeckSlide.custom(
          builder: (context) => ColoredBox(
            color: theme.colorScheme.primaryContainer,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GridPaper(
                    interval: 200,
                    color: theme.colorScheme.primaryFixedDim,
                    divisions: 1,
                    child: SizedBox.expand(),
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
                Center(
                  child: DragDismissable.custom(
                    onDismiss: () => FlutterDeck.of(context).next(),
                    motion: CupertinoMotion.bouncy(),
                    child: Heroine(
                      tag: true,
                      motion: CupertinoMotion.bouncy(),
                      child: LiquidGlass(
                        settings: LiquidGlassSettings(
                          refractiveIndex: 1.15,
                          thickness: thickness * 100,
                          lightIntensity: thickness * 1,
                          chromaticAberration: 1,
                          lightness: 1 + .03 * thickness,
                          saturation: 1 + .05 * thickness,
                        ),
                        shape: LiquidOval(),
                        child: ColoredBox(
                          color: Colors.transparent,
                          child: SizedBox.square(
                            dimension: 700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
