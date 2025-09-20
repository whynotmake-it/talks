import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:physical_ui/slides/audio/audio_category_slide.dart';
import 'package:physical_ui/slides/audio/sound_haptics_slide.dart';
import 'package:physical_ui/slides/dimensionality_slides.dart';
import 'package:physical_ui/slides/glass_slide.dart';
import 'package:physical_ui/slides/history/slides/command_line_slide.dart';
import 'package:physical_ui/slides/history/slides/gui_system1_slide.dart';
import 'package:physical_ui/slides/history/slides/iphone_notes_physics_slide.dart';
import 'package:physical_ui/slides/history/slides/material_notes_flat_slide.dart';
import 'package:physical_ui/slides/history/slides/osx_aqua_slide.dart';
import 'package:physical_ui/slides/how_did_we_get_here_slide.dart';
import 'package:physical_ui/slides/motion_slides.dart';
import 'package:physical_ui/slides/motor_title_slide.dart';
import 'package:physical_ui/slides/simulation_vs_curve_slides.dart';
import 'package:physical_ui/slides/surfaces_slides.dart';
import 'package:physical_ui/slides/title_slide.dart';
import 'package:wnma_talk/big_quote_template.dart';
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
            BigQuoteTemplate(title: Text("Part 2: Audio")),
            AudioCategorySlide(),
            SoundHapticsSlide(),
            TitleSlide(),
            GlassSlide(),
            HowDidWeGetHereSlide(),
            CommandLineSlide(),
            GuiSystem1Slide(),
            AquaStickiesSlide(),
            MaterialNotesFlatSlide(),
            IphoneNotesPhysicsSlide(),
            BigQuoteTemplate(title: Text("Part 1: Surfaces")),
            ...surfacesSlides,

            BigQuoteTemplate(title: Text("Part 2: Motion")),
            ...motionSlides,
            BigQuoteTemplate(title: Text("Well, it's settled then!")),
            ...dimensionalitySlides,
            SimulationVsCurveSlide(),
            MotorTitleSlide(),
          ],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
