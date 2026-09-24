import 'package:build_to_burn/font_licenses.dart';
import 'package:build_to_burn/shared/deck_theme.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/slides/fixes_slide.dart';
import 'package:build_to_burn/slides/frame_pipeline_slide.dart';
import 'package:build_to_burn/slides/gpu_profiling_slide.dart';
import 'package:build_to_burn/slides/hook_slide.dart';
import 'package:build_to_burn/slides/painting_vs_compositing_slide.dart';
import 'package:build_to_burn/slides/production_slide.dart';
import 'package:build_to_burn/slides/thanks_slide.dart';
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
    return FittedBox(
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
          slides: const [
            TitleSlide(),
            HookSlide(),
            FramePipelineSlide(),
            PaintingVsCompositingSlide(),
            GpuProfilingSlide(),
            FixesSlide(),
            ProductionSlide(),
            ThanksSlide(),
          ],
        ),
      ),
    );
  }
}
