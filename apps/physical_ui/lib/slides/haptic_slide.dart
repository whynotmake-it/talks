import 'package:flutter/material.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/video.dart';
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _HapticColumn(
            title: 'Contact',
            videoPath: 'assets/contact.MP4',
          ),
          _HapticColumn(
            title: 'Confirm',
            videoPath: 'assets/confirm.MP4',
          ),
          _HapticColumn(
            title: 'Continuity',
            videoPath: 'assets/continuity.MP4',
          ),
        ],
      ),
     
    );
  }
}

class _HapticColumn extends StatelessWidget {
  const _HapticColumn({
    required this.title,
    required this.videoPath,
  });

  final String title;
  final String videoPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 24,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          height: 2778 /4,
          width: 1284/4,
          child: Video(
            assetKey: videoPath,
   
          ),
        ),
      ],
    );
  }
}
