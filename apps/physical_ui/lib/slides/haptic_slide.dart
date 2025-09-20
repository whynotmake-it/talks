import 'package:flutter/material.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HapticSlide extends FlutterDeckSlideWidget {
  const HapticSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            title: 'Haptic Feedback',
            route: '/haptic-feedback',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: const Text('Haptic Feedback'),
      mainContent: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _HapticColumn(
              title: 'Contact',
              imagePath: 'assets/keyboard.png',
            ),
          ),
          Expanded(
            child: _HapticColumn(
              title: 'Confirm',
              imagePath: 'assets/faceid.png',
            ),
          ),
          Expanded(
            child: _HapticColumn(
              title: 'Continuity',
              imagePath: 'assets/timers.png',
            ),
          ),
        ],
      ),
     
    );
  }
}

class _HapticColumn extends StatelessWidget {
  const _HapticColumn({
    required this.title,
    required this.imagePath,
  });

  final String title;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Image.asset(
            imagePath,
            height: 600,
          ),
        ],
      ),
    );
  }
}
