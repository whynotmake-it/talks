import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wnma_talk/wnma_talk.dart';

class AudioCategorySlide extends FlutterDeckSlideWidget {
  const AudioCategorySlide({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const _AudioCategoryContent(),
    );
  }
}

class _AudioCategoryContent extends HookWidget {
  const _AudioCategoryContent();

  @override
  Widget build(BuildContext context) {
    final currentlyPlaying = useState<String?>(null);
    final audioPlayer = useMemoized(AudioPlayer.new);
    final playerState = useState<PlayerState?>(null);
    
    // Listen to player state changes
    useEffect(() {
      final subscription = audioPlayer.playerStateStream.listen((state) {
        playerState.value = state;
        // Clear currently playing when audio completes
        if (state.processingState == ProcessingState.completed) {
          currentlyPlaying.value = null;
        }
      });
      
      return subscription.cancel;
    }, [audioPlayer]);
    
    // Dispose audio player when widget is disposed
    useEffect(() {
      return audioPlayer.dispose;
    }, []);
    
    Future<void> playSound(String soundPath) async {
      try {
        if (currentlyPlaying.value == soundPath && 
            playerState.value?.playing == true) {
          // Stop if already playing
          await audioPlayer.stop();
          currentlyPlaying.value = null;
        } else {
          // Stop any current sound and play new one
          await audioPlayer.stop();
          await audioPlayer.setAsset(soundPath);
          currentlyPlaying.value = soundPath;
          await audioPlayer.play();
        }
      } catch (e) {
        // Handle audio loading/playing errors gracefully
        currentlyPlaying.value = null;
        debugPrint('Error playing sound: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.all(100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Categories',
            style: FlutterDeckTheme.of(context).textTheme.header,
          ),
          const SizedBox(height: 80),
          Expanded(
            child: Row(
              children: [
                // Sonic Identity Column
                Expanded(
                  child: _AudioCategory(
                    title: 'Sonic Identity',
                    sounds: [
                      _AudioItem(
                        name: 'System Start',
                        path: 'assets/windows_start.mp3',
                        isPlaying: currentlyPlaying.value == 'assets/windows_start.mp3' && 
                                   playerState.value?.playing == true,
                        onTap: () => playSound('assets/windows_start.mp3'),
                      ),
                      _AudioItem(
                        name: 'Goodbye',
                        path: 'assets/windows_off.mp3',
                        isPlaying: currentlyPlaying.value == 'assets/windows_off.mp3' && 
                                   playerState.value?.playing == true,
                        onTap: () => playSound('assets/windows_off.mp3'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                
                // Passive Sounds Column
                Expanded(
                  child: _AudioCategory(
                    title: 'Passive Sounds',
                    sounds: [
                      _AudioItem(
                        name: 'Call for Attention',
                        path: 'assets/iphone_ringtone.mp3',
                        isPlaying: currentlyPlaying.value == 'assets/iphone_ringtone.mp3' && 
                                   playerState.value?.playing == true,
                        onTap: () => playSound('assets/iphone_ringtone.mp3'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                
                // Active Sounds Column
                Expanded(
                  child: _AudioCategory(
                    title: 'Active Sounds',
                    sounds: [
                                 _AudioItem(
                        name: 'Amplify Meaning',
                        path: 'assets/error.mp3',
                        isPlaying: currentlyPlaying.value == 'assets/error.mp3' && 
                                   playerState.value?.playing == true,
                        onTap: () => playSound('assets/error.mp3'),
                      ),
                      _AudioItem(
                        name: 'Amplify Physicality',
                        path: 'assets/iphone_keyboard.mp3',
                        isPlaying: currentlyPlaying.value == 'assets/iphone_keyboard.mp3' && 
                                   playerState.value?.playing == true,
                        onTap: () => playSound('assets/iphone_keyboard.mp3'),
                      ),
                
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioCategory extends StatelessWidget {
  const _AudioCategory({
    required this.title,
    required this.sounds,
  });

  final String title;
  final List<_AudioItem> sounds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FlutterDeckTheme.of(context).textTheme.subtitle,
        ),
        const SizedBox(height: 40),
        ...sounds.map(
          (sound) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: sound,
          ),
        ),
      ],
    );
  }
}

class _AudioItem extends StatelessWidget {
  const _AudioItem({
    required this.name,
    required this.path,
    required this.isPlaying,
    required this.onTap,
  });

  final String name;
  final String path;
  final bool isPlaying;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.materialTheme.colorScheme.outline,
              width: 2,
            ),
            color: isPlaying 
                ? theme.materialTheme.colorScheme.primaryContainer
                : theme.materialTheme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 48,
                color: isPlaying 
                    ? theme.materialTheme.colorScheme.primary
                    : theme.materialTheme.colorScheme.onSurface,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium.copyWith(
                    color: isPlaying 
                        ? theme.materialTheme.colorScheme.onPrimaryContainer
                        : theme.materialTheme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
