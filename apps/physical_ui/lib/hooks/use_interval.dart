import 'dart:async';

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
