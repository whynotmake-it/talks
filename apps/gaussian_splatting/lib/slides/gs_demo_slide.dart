import 'dart:ui';

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
        backgroundColor: const Color(0xFF0A0A0A),
        body: SizedBox.expand(
          child: Stack(
            children: const [
              // Background draggable text (behind the car)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 200),
                  child: _TextWidget(
                    text: 'BACKGROUND',
                  
                    color: Colors.white,
                    fontSize: 164,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              
              // Gaussian Splatter Widget (middle layer - the car)
              GaussianSplatterWidget(
                assetPath: 'assets/toycar.ply',
                disableAlphaWrite: false,
              ),
              
              // Frosted glass box
              _DraggableGlassBox(
                initialPosition: Offset(1400, 300),
              ),
              
              // Foreground draggable text (in front of everything)
              _DraggableText(
                text: 'FOREGROUND',
                initialPosition: Offset(1200, 800),
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableText extends StatefulWidget {
  const _DraggableText({
    required this.text,
    required this.initialPosition,
    required this.color,
    this.fontWeight = FontWeight.normal,
  });

  final String text;
  final Offset initialPosition;
  final Color color;
  final FontWeight fontWeight;

  @override
  State<_DraggableText> createState() => _DraggableTextState();
}

class _DraggableTextState extends State<_DraggableText> {
  late Offset position;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position = position + details.delta;
          });
        },
        child: _TextWidget(
          text: widget.text,
          color: widget.color,
  
          fontWeight: widget.fontWeight,
        ),
      ),
    );
  }
}

class _TextWidget extends StatelessWidget {
  const _TextWidget({
    required this.text,
    required this.color,
    this.fontSize = 48,
    this.fontWeight = FontWeight.normal,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class _DraggableGlassBox extends StatefulWidget {
  const _DraggableGlassBox({
    required this.initialPosition,
  });

  final Offset initialPosition;

  @override
  State<_DraggableGlassBox> createState() => _DraggableGlassBoxState();
}

class _DraggableGlassBoxState extends State<_DraggableGlassBox> {
  late Offset position;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position = position + details.delta;
          });
        },
        child: const _GlassBox(),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({this.opacity = 1.0});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05 * opacity),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.blur_on,
                    color: Colors.white.withOpacity(0.6 * opacity),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'GLASS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8 * opacity),
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
