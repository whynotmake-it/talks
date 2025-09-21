import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

const jesperSlideNotesHeader = 'Jesper:';
const timSlideNotesHeader = 'Tim:';

enum SlideSpeaker {
  jesper,
  tim,
}

class SlideNumber extends StatelessWidget {
  const SlideNumber({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final header = FlutterDeck.of(
      context,
    ).configuration.speakerNotes.split('\n').first.trim();

    final speaker = switch (header) {
      jesperSlideNotesHeader => SlideSpeaker.jesper,
      timSlideNotesHeader => SlideSpeaker.tim,
      _ => null,
    };

    return Stack(
      children: [
        child,
        if (speaker case final speaker?)
          Positioned(
            top: 32,
            left: speaker == SlideSpeaker.jesper ? null : 32,
            right: speaker == SlideSpeaker.tim ? null : 32,
            child: Badge(
              backgroundColor: switch (speaker) {
                SlideSpeaker.jesper => Colors.green,
                SlideSpeaker.tim => Colors.blueAccent,
              },
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Text(FlutterDeck.of(context).slideNumber.toString()),
        ),
      ],
    );
  }
}
