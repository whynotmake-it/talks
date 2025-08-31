import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

class SlideNumber extends StatelessWidget {
  const SlideNumber({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 16,
          right: 16,
          child: Text(FlutterDeck.of(context).slideNumber.toString()),
        ),
      ],
    );
  }
}
