import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:physical_ui/slides/glass_slide.dart';
import 'package:physical_ui/slides/how_did_we_get_here_slide.dart';
import 'package:physical_ui/slides/motion_slide.dart';
import 'package:physical_ui/slides/motion_slides.dart';
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
            controls: FlutterDeckControlsConfiguration(
              presenterToolbarVisible: false,
            ),
          ),
          slides: [
            TitleSlide(),
            GlassSlide(),
            HowDidWeGetHereSlide(),
            MotionSlideNoAnimation(),
          ],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
