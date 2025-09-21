import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class SoundHapticsSlide extends FlutterDeckSlideWidget {
  const SoundHapticsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/audio/sound-haptics',
          title: 'Audio as Haptic Proxy',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(child: const _SoundHapticsContent()),
    );
  }
}

class _SoundHapticsContent extends HookWidget {
  const _SoundHapticsContent();

  @override
  Widget build(BuildContext context) {
    final selectedDate = useState(DateTime.now());
    final previousDate = useRef<DateTime?>(null);
    final audioPlayer = useMemoized(AudioPlayer.new);

    // Dispose audio player when widget is disposed
    useEffect(() {
      return audioPlayer.dispose;
    }, []);

    // Play tick sound when date changes
    useEffect(() {
      if (previousDate.value != null &&
          previousDate.value != selectedDate.value) {
        // Play the actual tick.m4a file for authentic iOS sound
        audioPlayer
            .setAsset('assets/tick.m4a')
            .then((_) {
              audioPlayer
                ..seek(Duration.zero) // Reset to beginning
                ..play();
            })
            .catchError((e) {
              debugPrint('Error playing tick sound: $e');
            });
      }
      previousDate.value = selectedDate.value;
      return null;
    }, [selectedDate.value]);

    return Padding(
      padding: const EdgeInsets.all(100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio as Haptic Proxy',
            style: FlutterDeckTheme.of(context).textTheme.header,
          ),

          Expanded(
            child: Row(
              children: [
                // Date Picker Demo Section
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      height: 800,
                      decoration: BoxDecoration(
                        color: FlutterDeckTheme.of(
                          context,
                        ).materialTheme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: FlutterDeckTheme.of(
                            context,
                          ).materialTheme.colorScheme.outline,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                fontSize: 22,
                                color: FlutterDeckTheme.of(
                                  context,
                                ).materialTheme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: selectedDate.value,
                            onDateTimeChanged: (DateTime newDate) {
                              selectedDate.value = newDate;
                            },
                          ),
                        ),
                      ),
                    ),
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
