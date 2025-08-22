import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

int useInterval({
  required Duration interval,
  List<Object?>? keys,
}) {
  final changes = useState(0);

  useEffect(
    () {
      final timer = Timer.periodic(interval, (v) {
        changes.value++;
      });
      return timer.cancel;
    },
    [interval, ...?keys],
  );

  return changes.value;
}

/// Super stupid unsafe way to use something memoized and dispose it afterwards
T useDisposable<T>(
  T Function() create, {
  void Function(T it)? dispose,
}) {
  void defaultDispose(T it) {
    if (it case final ChangeNotifier it) {
      it.dispose();
    } else {
      try {
        (it as dynamic).dispose();
        // ignore: avoid_catching_errors
      } on NoSuchMethodError catch (_) {}
    }
  }

  final disposeCallback = dispose ?? defaultDispose;

  final it = useMemoized(create);

  useEffect(() {
    return () => disposeCallback(it);
  }, [it]);

  return it;
}
