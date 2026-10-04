import 'package:build_to_burn/font_licenses.dart';
import 'package:build_to_burn/shared/deck_theme.dart';
import 'package:build_to_burn/shared/flow_notes.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/slides/gpu_chapter_slide.dart';
import 'package:build_to_burn/slides/live_slides.dart';
import 'package:build_to_burn/slides/render_stack_slides.dart';
import 'package:build_to_burn/slides/skeleton.dart';
import 'package:build_to_burn/slides/title_slide.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(const BuildToBurnTalk());
}

class BuildToBurnTalk extends StatelessWidget {
  const BuildToBurnTalk({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowNotesShortcut(
      child: FittedBox(
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: FlutterDeckApp(
            lightTheme: buildDeckTheme(Palette.light, Brightness.light),
            darkTheme: buildDeckTheme(Palette.dark, Brightness.dark),
            themeMode: ThemeMode.light,
            configuration: const FlutterDeckConfiguration(
              showProgress: false,
              transition: FlutterDeckTransition.fade(),
              controls: FlutterDeckControlsConfiguration(
                presenterToolbarVisible: false,
              ),
            ),
            slides: [
              const TitleSlide(),
              coldOpenSlide,
              hookSlide,
              stage2Slide,
              paintSourceSlide,
              stage3Slide,
              stage4Slide,
              stage5Slide,
              const GpuChapterSlide(),
              stage6Slide,
              const LiveSlide(),
              const EveryFrameSlide(),
              quizAnswerSlide,
              ahaSlide,
              const FastNotCheapSlide(),
              profilingSlide,
              fixesSlide,
              productionSlide,
              closeSlide,
              // Backup, for questions.
              framesSlide,
              limitsSlide,
            ],
          ),
        ),
      ),
    );
  }
}
