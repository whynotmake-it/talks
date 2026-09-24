import 'package:build_to_burn/design/style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Wraps a slide element so it fades and rises in with the others.
typedef RevealBuilder = Widget Function(int index, Widget child);

/// Reveals [count] elements one after another when the slide appears.
///
/// All elements run on one [TrackBuilder], one [Track] each, so they share a
/// single ticker and can be scrubbed in motor_devtools.
class Entrance extends StatefulWidget {
  const Entrance({
    required this.count,
    required this.builder,
    this.stagger = const Duration(milliseconds: 70),
    this.debugLabel = 'Slide entrance',
    super.key,
  });

  final int count;
  final Duration stagger;
  final String debugLabel;

  /// Builds the slide. Wrap each element with `reveal(index, child)`.
  final Widget Function(BuildContext context, RevealBuilder reveal) builder;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  late List<Track<double>> _tracks = _createTracks();

  List<Track<double>> _createTracks() => [
    for (var i = 0; i < widget.count; i++)
      Track<double>(.single, initial: 0, debugLabel: 'Element ${i + 1}'),
  ];

  @override
  void didUpdateWidget(Entrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) _tracks = _createTracks();
  }

  @override
  Widget build(BuildContext context) {
    return TrackBuilder(
      debugLabel: widget.debugLabel,
      animations: [
        for (final (index, track) in _tracks.indexed)
          track([
            .hold(widget.stagger * index),
            const .to(1, motion: .curved(Duration(milliseconds: 500), easeOut)),
          ]),
      ],
      builder: (context, value, _) => widget.builder(
        context,
        (index, child) => Reveal(
          progress: value(_tracks[index]),
          blur: 0,
          child: child,
        ),
      ),
    );
  }
}
