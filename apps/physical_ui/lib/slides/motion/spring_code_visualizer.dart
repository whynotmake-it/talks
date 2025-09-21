import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:wnma_talk/code_highlight.dart';

class SpringCodeVisualizer extends HookWidget {
  const SpringCodeVisualizer({
    required this.duration,
    required this.bounce,
    super.key,
  });

  final ValueNotifier<Duration> duration;
  final ValueNotifier<double> bounce;

  @override
  Widget build(BuildContext context) {
    useListenable(
      Listenable.merge([
        duration,
        bounce,
      ]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 32,
      children: [
        Row(
          spacing: 32,
          children: [
            Text('Duration:'),
            Expanded(
              child: CupertinoSlider(
                value: duration.value.inMilliseconds.toDouble(),
                onChanged: (value) {
                  duration.value = Duration(milliseconds: value.toInt());
                },
                min: 1,
                max: 1000,
              ),
            ),
          ],
        ),
        Row(
          spacing: 32,
          children: [
            Text('Bounce:'),
            Expanded(
              child: CupertinoSlider(
                value: bounce.value,
                onChanged: (value) {
                  bounce.value = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 200),
        Flexible(
          child: CodeHighlight(
            code:
                '''
final spring = SpringDescription
  .withDurationAndBounce(
    duration: Duration(
      milliseconds: ${duration.value.inMilliseconds}
    ),
    bounce: ${bounce.value.toStringAsFixed(2)},
  );''',
          ),
        ),
      ],
    );
  }
}
