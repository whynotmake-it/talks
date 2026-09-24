import 'package:build_to_burn/design/deck_theme.dart';
import 'package:build_to_burn/design/style.dart';
import 'package:build_to_burn/font_licenses.dart';
import 'package:build_to_burn/slides/section_slides.dart';
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
            transition: FlutterDeckTransition.fade(),
            controls: FlutterDeckControlsConfiguration(
              presenterToolbarVisible: false,
            ),
          ),
          slides: const [
            TitleSlide(),
            ...sectionSlides,
          ],
        ),
      ),
    );
  }
}
