import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:physical_ui/slides/1_surfaces/code_slides.dart';
import 'package:physical_ui/slides/1_surfaces/surfaces_slides.dart';
import 'package:physical_ui/slides/audio/audio_category_slide.dart';
import 'package:physical_ui/slides/audio/sound_haptics_slide.dart';
import 'package:physical_ui/slides/box_stoss_slide.dart';
import 'package:physical_ui/slides/design_system_slide.dart';
import 'package:physical_ui/slides/dimensionality_slides.dart';
import 'package:physical_ui/slides/glass_slide.dart';
import 'package:physical_ui/slides/haptic_slide.dart';
import 'package:physical_ui/slides/history/flat/flat_slides.dart';
import 'package:physical_ui/slides/history/slides/command_line_slide.dart';
import 'package:physical_ui/slides/history/slides/gui_system1_slide.dart';
import 'package:physical_ui/slides/history/slides/iphone_notes_physics_slide.dart';
import 'package:physical_ui/slides/history/slides/material_notes_flat_slide.dart';
import 'package:physical_ui/slides/history/slides/objects_and_metaphors_slide.dart';
import 'package:physical_ui/slides/history/slides/osx_aqua_slide.dart';
import 'package:physical_ui/slides/history/slides/shading_animation_slide.dart';
import 'package:physical_ui/slides/history/what_next/slides.dart';
import 'package:physical_ui/slides/how_did_we_get_here_slide.dart';
import 'package:physical_ui/slides/motion_character_slide.dart';
import 'package:physical_ui/slides/motion_slides.dart';
import 'package:physical_ui/slides/motor_card_stack_slide.dart';
import 'package:physical_ui/slides/motor_title_slide.dart';
import 'package:physical_ui/slides/simulation_vs_curve_slides.dart';
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
            TitleSlide(),
            GlassSlide(),
            HowDidWeGetHereSlide(),

            CommandLineSlide(),
            ObjectsAndMetaphorsSlide(),
            ShadingAnimationSlide(),

            BigQuoteTemplate(title: Text("A sudden shift.")),
            ...flatSlides,

            BigQuoteTemplate(title: Text("What next?")),
            ...whatNextSlides,

            DesignSystemSlide(),

            BigQuoteTemplate(title: Text("Part 1: Surfaces")),
            ...surfacesSlides,
            ...surfacesCodeSlides,

            BigQuoteTemplate(title: Text("Part 2: Audio")),
            AudioCategorySlide(),
            BoxStossSlide(),
            SoundHapticsSlide(),

            BigQuoteTemplate(title: Text("Part 3: Haptic")),
            HapticSlide(),

            BigQuoteTemplate(title: Text("Part 4: Motion")),
            ...motionSlides,
            MotionCharacterSlide(),

            BigQuoteTemplate(title: Text("Well, it's settled then!")),
            ...dimensionalitySlides,
            SimulationVsCurveSlide(),
            MotorTitleSlide(),

            MotorCardStackSlide(),
          ],
          themeMode: ThemeMode.light,
        ),
      ),
    );
  }
}
