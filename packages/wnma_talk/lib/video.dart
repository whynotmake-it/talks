import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:rivership/rivership.dart';
import 'package:video_player/video_player.dart';

VideoPlayerController useVideoPlayerController(
  String assetKey, {
  bool play = true,
  bool loop = true,
}) {
  final videoPlayerController = useMemoized(
    () => VideoPlayerController.asset(assetKey),
    [assetKey],
  );
  final value = useValueListenable(videoPlayerController);

  useEffect(
    () {
      videoPlayerController.initialize();
      return videoPlayerController.dispose;
    },
    [videoPlayerController],
  );

  useEffect(
    () {
      if (value.isInitialized) {
        if (play) {
          videoPlayerController.play();
        } else {
          videoPlayerController.pause();
        }
      }

      videoPlayerController.setLooping(loop);
      return null;
    },
    [value.isInitialized, play, loop, videoPlayerController],
  );

  return videoPlayerController;
}

class Video extends HookWidget {
  const Video({
    required this.assetKey,
    super.key,
    this.play = true,
    this.loop = true,
  });

  final String assetKey;

  final bool play;

  final bool loop;

  @override
  Widget build(BuildContext context) {
    final videoPlayerController = useVideoPlayerController(
      assetKey,
      play: play,
      loop: loop,
    );

    final initialized = useValueListenable(videoPlayerController).isInitialized;

    return AnimatedSizeSwitcher(
      child: initialized
          ? VideoPlayer(videoPlayerController)
          : const SizedBox.expand(),
    );
  }
}
