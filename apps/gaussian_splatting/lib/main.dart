import 'package:flutter/material.dart';
import 'package:gaussian_splatting/slides/ar_video_slide.dart';
import 'package:gaussian_splatting/slides/classic_rendering_slide.dart';
import 'package:gaussian_splatting/slides/food_video_slide.dart';
import 'package:gaussian_splatting/slides/gaussian_splatting_slide.dart';
import 'package:gaussian_splatting/slides/gaussian_splatting_slide2.dart';
import 'package:gaussian_splatting/slides/gs_demo_slide.dart';
import 'package:gaussian_splatting/slides/how_to_slide.dart';
import 'package:gaussian_splatting/slides/implementation_slide.dart';
import 'package:gaussian_splatting/slides/learning_challenge_slide.dart';
import 'package:gaussian_splatting/slides/learning_query_slide.dart';
import 'package:gaussian_splatting/slides/maps_video_slide.dart';
import 'package:gaussian_splatting/slides/nerf_slide.dart';
import 'package:gaussian_splatting/slides/novel_view_syn_slide.dart';
import 'package:gaussian_splatting/slides/radiance_field_slide.dart';
import 'package:gaussian_splatting/slides/rendering_slide_2.dart';
import 'package:gaussian_splatting/slides/rendering_slide_3.dart';
import 'package:gaussian_splatting/slides/rendering_slide_4.dart';
import 'package:gaussian_splatting/slides/rendering_slide_5.dart';
import 'package:gaussian_splatting/slides/rendering_slide_6.dart';
import 'package:gaussian_splatting/slides/thanks_slide.dart';
import 'package:gaussian_splatting/slides/title_slide.dart';
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
          themeMode: ThemeMode.light,
          lightTheme: buildGaussianSplattingTheme(),
          darkTheme: buildGaussianSplattingTheme(),
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
          slides: const [
            TitleSlide(),
            ClassicRenderingSlide(),
            NovelViewSynSlide(),
            LearningQuerySlide(),
            LearningChallengeSlide(),
            RadianceFieldSlide(),
            NerfSlide(),
            GaussianSplattingSlide(),
            GaussianSplattingSlide2(),
            ImplementationSlide(),
            // RenderingSlide1(),
            RenderingSlide2(),
            RenderingSlide3(),
            RenderingSlide4(),
            RenderingSlide5(),
            RenderingSlide6(),
            GaussianSplatterDemoSlide(),
            HowToSlide(),
            FoodVideoSlide(),
            ArVideoSlide(),
            MapsVideoSlide(),
            ThanksSlide(),
          ],
        ),
      ),
    );
  }
}
