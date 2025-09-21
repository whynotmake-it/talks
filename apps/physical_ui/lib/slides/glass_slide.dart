import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GlassSlide extends FlutterDeckSlideWidget {
  const GlassSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/glass',
          steps: 2,
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            return Stack(
              children: [
                Positioned.fill(
                  child: SingleMotionBuilder(
                    motion: CupertinoMotion.smooth(),
                    value: step == 1 ? 0.0 : 20.0,
                    child: Video(
                      assetKey: 'assets/glass.mp4',
                      play: step == 1,
                    ),
                    builder: (context, value, child) => ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        tileMode: TileMode.mirror,
                        sigmaX: value,
                        sigmaY: value,
                      ),
                      child: child,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(100),
                  child: _Comments(hidden: step == 1),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Comments extends StatelessWidget {
  const _Comments({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.bottomLeft,
          child: _Comment(
            stagger: 2,
            assetKey: 'assets/hate-tweet-1.png',
            translation: hidden ? Offset(-800, 800) : Offset.zero,
            rotation: hidden ? 0 : -.04,
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: _Comment(
            stagger: 1,
            assetKey: 'assets/hate-tweet-2.png',
            translation: hidden ? Offset(800, 800) : Offset.zero,
            rotation: hidden ? -0.2 : 0.2,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: _Comment(
            assetKey: 'assets/hate-tweet-3.png',
            translation: hidden ? Offset(000, -800) : Offset.zero,
            rotation: hidden ? 0.1 : -0.1,
          ),
        ),
      ],
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({
    required this.assetKey,
    required this.translation,
    required this.rotation,
    this.stagger = 0,
  });
  final int stagger;

  final String assetKey;

  final Offset translation;

  final double rotation;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 500) +
          Duration(milliseconds: 100 * stagger),
    );
    return MotionBuilder(
      value: translation,
      motion: motion,
      converter: OffsetMotionConverter(),
      builder: (context, value, child) => Transform.translate(
        offset: value,
        child: SingleMotionBuilder(
          value: rotation,
          motion: motion,
          child: child,
          builder: (context, value, child) => Transform.rotate(
            angle: value,
            child: child,
          ),
        ),
      ),
      child: Material(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 10,
        child: Image.asset(
          assetKey,
          width: 700,
        ),
      ),
    );
  }
}
