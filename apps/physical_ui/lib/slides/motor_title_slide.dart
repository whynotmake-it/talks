import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotorTitleSlide extends FlutterDeckSlideWidget {
  const MotorTitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return BigQuoteTemplate(
      title: const _Logo(),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data:
          CupertinoTheme.of(
            context,
          ).copyWith(
            textTheme: CupertinoTheme.of(context).textTheme.copyWith(
              textStyle: TextStyle(
                fontFamily: 'Archivo',
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                letterSpacing: 1,
                fontVariations: const [
                  FontVariation.weight(500),
                  FontVariation.width(200),
                ],
              ),
            ),
          ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            MotorLogo('Motor'),
          ],
        ),
      ),
    );
  }
}

class MotorLogo extends StatelessWidget {
  const MotorLogo(
    this.value, {
    this.visible = true,
    super.key,
  });

  final String value;

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      motion: CupertinoMotion.smooth(),
      value: visible ? 1 : 0,
      builder: (context, opacity, _) => Visibility(
        visible: opacity >= 0.01,
        child: Opacity(
          opacity: opacity.clamp(0, 1),
          child: RichText(
            key: ValueKey(true),
            text: TextSpan(
              children: [
                for (final (index, char) in value.runes.indexed)
                  WidgetSpan(
                    child: _Letter(
                      index: index,
                      letter: String.fromCharCode(char),
                      visible: visible,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Letter extends StatefulWidget {
  const _Letter({
    required this.letter,
    required this.index,
    required this.visible,
  });

  final String letter;

  final int index;

  final bool visible;

  @override
  State<_Letter> createState() => _LetterState();
}

class _LetterState extends State<_Letter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final additionalDuration = Duration(milliseconds: widget.index * 200);
    final motion = CupertinoMotion.bouncy(
      extraBounce: .3,
      duration: Durations.extralong4,
    );

    final initialStyle = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(
          fontSize: 64,
          fontVariations: [FontVariation.weight(100), FontVariation.width(50)],
        );
    return MouseRegion(
      onEnter: (event) => setState(() => _hovered = true),
      onExit: (event) => setState(() => _hovered = false),
      child: MotionBuilder(
        motion: motion.copyWith(duration: motion.duration + additionalDuration),
        from: initialStyle,
        value: widget.visible
            ? initialStyle.copyWith(
                fontSize: widget.visible ? 64 : 0,
                fontVariations: [
                  FontVariation.weight(_hovered ? 900 : 700),
                  FontVariation.width(110),
                ],
              )
            : initialStyle,
        converter: FontMotionConverter(),
        builder: (context, value, child) {
          return SingleMotionBuilder(
            motion: motion,
            from: -50,
            value: widget.visible ? 0 : -50,
            builder: (context, xOffset, child) => Transform.translate(
              offset: Offset(xOffset, 0),
              child: child,
            ),
            child: Text(
              textHeightBehavior: TextHeightBehavior(),
              widget.letter,
              style: value,
            ),
          );
        },
      ),
    );
  }
}

class FontMotionConverter implements MotionConverter<TextStyle> {
  late TextStyle latestValue;

  @override
  List<double> normalize(TextStyle value) {
    latestValue = value;
    return [
      value.fontSize!,
      value.fontVariations!.firstWhere((v) => v.axis == 'wght').value,
      value.fontVariations!.firstWhere((v) => v.axis == 'wdth').value,
    ];
  }

  @override
  TextStyle denormalize(List<double> values) {
    return latestValue.copyWith(
      fontSize: values[0],
      fontVariations: [
        FontVariation.weight(values[1].clamp(1, 900)),
        FontVariation.width(values[2].clamp(1, 900)),
      ],
    );
  }
}
