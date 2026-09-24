import 'package:build_to_burn/font_licenses.dart';
import 'package:build_to_burn/shared/deck_theme.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/slides/render_stack_slide.dart';
import 'package:build_to_burn/slides/skeleton.dart';
import 'package:build_to_burn/slides/title_slide.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
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
          slides: [
            const TitleSlide(),
            RenderStackSlide(
              route: '/cold-open',
              title: 'Cold open',
              section: '0',
              script: renderStackIntro,
              speakerNotes: _coldOpenNotes,
            ),
            hookSlide,
            uiThreadSlide,
            rasterSlide,
            paintVsCompositeSlide,
            blurCostSlide,
            profilingSlide,
            fixesSlide,
            productionSlide,
            closeSlide,
          ],
        ),
      ),
    );
  }
}

const _coldOpenNotes =
    '''
$timSlideNotesHeader
Key message: a frame goes build -> layout -> paint -> new Scene -> raster -> GPU -> display. DevTools sees the lower half well. The upper half is where phones get hot.
- The stack builds up plane by plane, from widget code to pixels; the dashed line is the CPU/GPU border.
- Dart runs on the platform main thread on iOS and Android (default since 3.29, mandatory now); the raster thread is separate (Guide 4).
- Every scheduled frame sends a new Scene on stable 3.47.5, even if nothing repainted (Guide 2).
- The raster thread replays the whole frame; a BackdropFilter blur adds a pass break and 3 blur passes on the GPU (Guide 5, 6.2).
- The DevTools raster bar is raster-thread CPU time, not GPU time (Guide 9.1).
- Pipelining: the UI thread prepares frame N+1 while frame N rasterizes (pipeline depth 2 on Metal, Guide 4).
- Labels are placeholders until docs/render-stack-visualization.md lands.''';
