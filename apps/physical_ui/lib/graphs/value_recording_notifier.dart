import 'dart:math';

import 'package:flutter/cupertino.dart';

typedef TimedValue<T> = (DateTime, T);

class ValueRecordingNotifier<T> extends ValueNotifier<List<T>> {
  ValueRecordingNotifier({
    this.window,
  }) : super([]);

  int? window;

  void reset() {
    value = [];
  }

  void record(T value) {
    this.value.add(value);

    this.value = switch (window) {
      final window? => this.value.sublist(
        max(this.value.length - window, 0),
        this.value.length,
      ),
      null => this.value,
    };
  }
}

class TimedValueRecordingNotifier<T>
    extends ValueNotifier<List<TimedValue<T>>> {
  TimedValueRecordingNotifier({
    this.window,
  }) : super([]);

  Duration? window;

  void reset() {
    value = [];
  }

  void record(T value) {
    this.value.add((DateTime.now(), value));

    this.value = switch (window) {
      final window? => this.value.window(window),
      null => this.value,
    };
  }
}

extension TimedValuesExtension<T> on List<TimedValue<T>> {
  List<(DateTime, T)> window(Duration duration) {
    final from = DateTime.now().subtract(duration);
    return subset(from: from);
  }

  List<(DateTime, T)> subset({
    DateTime? from,
    DateTime? to,
  }) {
    return where(
      (v) =>
          (to == null || v.$1.isBefore(to)) &&
          (from == null || v.$1.isAfter(from)),
    ).toList();
  }
}
