import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/wnma_talk.dart';

class BulletList extends StatelessWidget {
  const BulletList({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: children,
    );
  }
}

class BulletPoint extends StatelessWidget {
  const BulletPoint({
    required this.text,
    this.icon,
    this.visible = true,
    this.animateIn = true,
    super.key,
  });

  final bool visible;

  final bool animateIn;

  final Widget text;

  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final style = FlutterDeckTheme.of(context).textTheme.bodyLarge;
    return AnimatedVisibility(
      visible: visible,
      animateIn: animateIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text.rich(
            WidgetSpan(
              style: style,
              alignment: PlaceholderAlignment.middle,
              child: IconTheme.merge(
                data: IconThemeData(size: style.fontSize),
                child: icon ?? const Text('•'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: DefaultTextStyle(
              style: style,
              child: text,
            ),
          ),
        ],
      ),
    );
  }
}
