import 'package:flutter/cupertino.dart';

class ValueRecordingNotifier<T> extends ValueNotifier<List<(DateTime, T)>> {
  ValueRecordingNotifier() : super([]);

  List<(DateTime, T)> duration(Duration duration) {
    final from = DateTime.now().subtract(duration);
    return subset(from: from);
  }

  List<(DateTime, T)> subset({
    DateTime? from,
    DateTime? to,
  }) {
    return value
        .where(
          (v) =>
              (to == null || v.$1.isBefore(to)) &&
              (from == null || v.$1.isAfter(from)),
        )
        .toList();
  }

  void reset() {
    value = [];
  }

  void record(T value) {
    this.value = [
      ...this.value,
      (DateTime.now(), value),
    ];
  }
}
