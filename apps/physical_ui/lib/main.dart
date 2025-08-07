import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:physical_ui/slides/slide_two.dart';
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
            SlideTwo(),
          ],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
