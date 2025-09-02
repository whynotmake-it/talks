import 'package:flutter/material.dart';
import 'package:gaussian_splatting/slides/gs_demo_slide.dart';
import 'package:gaussian_splatting/slides/history_slide.dart';
import 'package:gaussian_splatting/slides/novel_view_syn_slide.dart';
import 'package:heroine/heroine.dart';
import 'package:wnma_talk/wnma_talk.dart';

void main() {
  runApp(const GaussianSplattingTalk());
}

class GaussianSplattingTalk extends StatelessWidget {
  const GaussianSplattingTalk({super.key});

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
          slides: const [HistorySlide(),NovelViewSynSlide(),GaussianSplatterDemoSlide(),],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
