import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// Where to go from here: the official GPU profiling guides and our agent
/// skills, each behind a QR code.
class DocsSkillsSlide extends FlutterDeckSlideWidget {
  const DocsSkillsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/docs-and-skills',
          title: 'Docs and skills',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  /// The Impeller docs in the Flutter repo: frame captures in Xcode and
  /// RenderDoc, and how to read them.
  static const _docsUrl =
      'https://github.com/flutter/flutter/tree/master/docs/engine/impeller/docs';

  /// The impeller_model skills in this repo.
  static const _skillsUrl =
      'https://github.com/whynotmake-it/talks/tree/main/packages/impeller_model/skills';

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
              SizedBox(
                height: 80,
                child: Text(
                  'Docs and skills',
                  style: archivo(48, weight: 500, color: p.text),
                ),
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LinkColumn(
                        label: 'DOCS · FLUTTER REPO',
                        items: [
                          'Xcode frame capture',
                          'Reading frame captures',
                          'RenderDoc on Android',
                        ],
                        url: _docsUrl,
                      ),
                    ),
                    SizedBox(width: 120),
                    Expanded(
                      child: _LinkColumn(
                        label: 'SKILLS · FOR YOUR AGENT',
                        items: [
                          'GPU cost',
                          'Frame demand',
                          'GPU profiling',
                        ],
                        url: _skillsUrl,
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

class _LinkColumn extends StatelessWidget {
  const _LinkColumn({
    required this.label,
    required this.items,
    required this.url,
  });

  final String label;
  final List<String> items;
  final String url;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: mono(28, weight: 700, color: p.textTertiary)),
        const SizedBox(height: 28),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(item, style: archivo(44, color: p.text)),
          ),
        const Spacer(),
        QrImageView(
          data: url,
          size: 300,
          padding: EdgeInsets.zero,
          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: p.text),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: p.text,
          ),
        ),
      ],
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
