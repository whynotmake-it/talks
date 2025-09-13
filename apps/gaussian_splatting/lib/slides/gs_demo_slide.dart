import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';

class GaussianSplatterDemoSlide extends FlutterDeckSlideWidget {
  const GaussianSplatterDemoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gs-demo',
          title: 'Gaussian Splatter Demo',
          speakerNotes: 'Interactive Gaussian Splatting demonstration',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,

        body: SizedBox.expand(
          child: const GaussianSplatterWidget(
            assetPath: 'assets/toycar.ply',
          ),
        ),
      ),
    );
  }
}
