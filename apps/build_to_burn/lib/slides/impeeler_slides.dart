import 'package:build_to_burn/shared/inline_mark.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The package: Impeller GPU estimates from a widget test, shown as the
/// report it writes for the talk's hook screen.
class ImpeelerSlide extends FlutterDeckSlideWidget {
  const ImpeelerSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/impeeler',
          title: 'Impeeler',
          speakerNotes:
              '$timSlideNotesHeader\n'
              'The win: it runs in a widget test, so an agent can change a '
              'widget, rerun, and read the pass count in seconds — no build, '
              'no device, no capture. Local package, not published. '
              'Screenshot of '
              'packages/impeeler/doc/hook_screen_with_the_name_dialog.html. '
              'The engine model is '
              'pinned to Flutter 3.47.1; numbers are estimates, real devices '
              'decide. No GPU milliseconds, energy, video or platform views.',
        ),
      );

  static const _bullets = [
    'No device, just a widget test',
    'Passes per widget',
    'Idle frame demand',
    'An estimate, not a profiler',
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'impeeler',
                      style: archivo(
                        92,
                        height: 1.05,
                        spacing: -3,
                        color: p.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: heat, width: 3),
                    ),
                    child: Text(
                      'EXPERIMENTAL',
                      style: mono(28, weight: 700, spacing: 2, color: heat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 56),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fast agentic iteration',
                            style: archivo(
                              64,
                              weight: 600,
                              height: 1.1,
                              spacing: -1,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(height: 48),
                          for (final bullet in _bullets)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  InlineMark(
                                    fontSize: 48,
                                    size: 12,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      color: p.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: archivo(
                                        48,
                                        height: 1.15,
                                        color: p.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 64),
                    AspectRatio(
                      aspectRatio: 1960 / 1690,
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(color: p.borderStrong, width: 2),
                        ),
                        child: Image.asset(
                          'assets/images/impeeler_report.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
