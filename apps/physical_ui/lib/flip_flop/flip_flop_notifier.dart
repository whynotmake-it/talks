import 'dart:async';

import 'package:flutter/material.dart';

class FlipFlopNotifier extends ValueNotifier<bool> {
  FlipFlopNotifier(this.duration) : super(false) {
    _startTimer();
  }

  Timer? _timer;

  final Duration duration;

  void flip() {
    value = !value;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      duration,
      (_) => value = !value,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
