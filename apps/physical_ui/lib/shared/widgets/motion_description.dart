import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

const _curvesWithNames = {
  Curves.linear: 'Curves.linear',
  Curves.ease: 'Curves.ease',
  Curves.easeIn: 'Curves.easeIn',
  Curves.easeOut: 'Curves.easeOut',
  Curves.easeInOut: 'Curves.easeInOut',
  Curves.fastOutSlowIn: 'Curves.fastOutSlowIn',
  Curves.slowMiddle: 'Curves.slowMiddle',
  Curves.bounceIn: 'Curves.bounceIn',
  Curves.bounceOut: 'Curves.bounceOut',
  Curves.bounceInOut: 'Curves.bounceInOut',
  Curves.elasticIn: 'Curves.elasticIn',
  Curves.elasticOut: 'Curves.elasticOut',
  Curves.elasticInOut: 'Curves.elasticInOut',
  Curves.decelerate: 'Curves.decelerate',
  Curves.fastLinearToSlowEaseIn: 'Curves.fastLinearToSlowEaseIn',
  Curves.easeInSine: 'Curves.easeInSine',
  Curves.easeOutSine: 'Curves.easeOutSine',
  Curves.easeInOutSine: 'Curves.easeInOutSine',
  Curves.easeInQuad: 'Curves.easeInQuad',
  Curves.easeOutQuad: 'Curves.easeOutQuad',
  Curves.easeInOutQuad: 'Curves.easeInOutQuad',
  Curves.easeInCubic: 'Curves.easeInCubic',
  Curves.easeOutCubic: 'Curves.easeOutCubic',
  Curves.easeInOutCubic: 'Curves.easeInOutCubic',
  Curves.easeInQuart: 'Curves.easeInQuart',
  Curves.easeOutQuart: 'Curves.easeOutQuart',
  Curves.easeInOutQuart: 'Curves.easeInOutQuart',
  Curves.easeInQuint: 'Curves.easeInQuint',
  Curves.easeOutQuint: 'Curves.easeOutQuint',
  Curves.easeInOutQuint: 'Curves.easeInOutQuint',
  Curves.easeInExpo: 'Curves.easeInExpo',
  Curves.easeOutExpo: 'Curves.easeOutExpo',
  Curves.easeInOutExpo: 'Curves.easeInOutExpo',
  Curves.easeInCirc: 'Curves.easeInCirc',
  Curves.easeOutCirc: 'Curves.easeOutCirc',
  Curves.easeInOutCirc: 'Curves.easeInOutCirc',
  Curves.easeInBack: 'Curves.easeInBack',
  Curves.easeOutBack: 'Curves.easeOutBack',
  Curves.easeInOutBack: 'Curves.easeInOutBack',
};

class MotionDescription extends StatelessWidget {
  const MotionDescription({
    required this.motion,
    super.key,
  });

  final Motion motion;

  @override
  Widget build(BuildContext context) {
    return Text(switch (motion) {
      CurvedMotion(:final curve) => _curvesWithNames[curve] ?? curve.toString(),
      SpringMotion() => 'Spring simulation',
      _ => 'Motion',
    });
  }
}
