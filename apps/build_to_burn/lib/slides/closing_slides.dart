import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// What to take home: a screen's GPU cost is its frames per second times the
/// price of each frame, and three things that keep both down.
class TakeawaysSlide extends FlutterDeckSlideWidget {
  const TakeawaysSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/takeaways',
          title: 'Takeaways',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  static const _items = [
    (
      'Let your screen settle',
      'No ticker without a visible change. Stop finished animations, mute '
          'hidden ones.',
    ),
    (
      'Know your expensive effects',
      'Blur, layers, blend modes, 3D and video: cheap once, costly on every '
          'frame. Clip them, group them, or fake them.',
    ),
    (
      "Fast isn't cheap",
      'DevTools says the frames are on time. Check energy and the GPU too, on '
          'a device, in profile mode.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          padding: const EdgeInsets.fromLTRB(120, 0, 120, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Cost = frames × price per frame', style: p.display),
              const SizedBox(height: 48),
              for (final (index, (title, detail)) in _items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${index + 1}',
                          style: mono(48, weight: 700, color: p.accent),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: archivo(48, weight: 500, color: p.text),
                            ),
                            const SizedBox(height: 8),
                            Text(detail, style: p.body),
                          ],
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

/// Our agent skills: each answers one question a developer asks about a
/// screen, in any app, starting from a widget test.
class SkillsSlide extends FlutterDeckSlideWidget {
  const SkillsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/skills',
          title: 'Skills',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  /// The impeller_model skills in this repo.
  static const _skillsUrl =
      'https://github.com/whynotmake-it/talks/tree/main/packages/impeller_model/skills';

  static const _skills = [
    ('Why is this screen expensive?', 'GPU cost'),
    ('Why does it keep drawing?', 'Frame demand'),
    ('What does it cost on a real phone?', 'GPU profiling'),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          padding: const EdgeInsets.fromLTRB(120, 0, 120, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Let your agent do the digging', style: p.display),
              const SizedBox(height: 64),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (question, skill) in _skills)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 36),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  SizedBox(
                                    width: 820,
                                    child: Text(
                                      question,
                                      style: archivo(44, color: p.text),
                                    ),
                                  ),
                                  Text(
                                    '→  $skill',
                                    style: mono(
                                      36,
                                      weight: 700,
                                      color: p.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Text(
                            'Works on any app: add impeller_model, write a '
                            'widget test, ask your agent.',
                            style: p.body,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'On our liquid glass package, fake glass read '
                            'the screen once per element. The new renderer '
                            'reads it once per screen.',
                            style: p.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 80),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        QrImageView(
                          data: _skillsUrl,
                          size: 300,
                          padding: EdgeInsets.zero,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: p.text,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: p.text,
                          ),
                        ),
                      ],
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

/// The last slide.
class ThankYouSlide extends FlutterDeckSlideWidget {
  const ThankYouSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/thank-you',
          title: 'Thank you',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('Thank you', style: p.hero),
              const SizedBox(height: 40),
              Text(
                'whynotmake.it',
                style: p.title.copyWith(color: p.textSecondary),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}
