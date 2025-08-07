import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/slides/title_slide.dart';
import 'package:wnma_talk/wnma_talk.dart';

void main() {
  runApp(const PhysicalUiTalk());
}

class PhysicalUiTalk extends StatelessWidget {
  const PhysicalUiTalk({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: 1920,
        height: 1080,
        child: FlutterDeckApp(
          lightTheme: buildTalkTheme(),
          darkTheme: buildTalkTheme(),
          navigatorObservers: [
            HeroineController(),
          ],
          configuration: FlutterDeckConfiguration(
            slideSize: FlutterDeckSlideSize.responsive(),
            showProgress: false,
            transition: FlutterDeckTransition.fade(),
          ),
          slides: [
            TitleSlide(),
            FlutterDeckSlide.custom(
              builder: (context) => Align(
                alignment: Alignment.centerLeft,
                child: Heroine(
                  motion: CupertinoMotion.bouncy(),
                  tag: true,
                  child: SizedBox.square(
                    dimension: 300,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: CircleBorder(),
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
