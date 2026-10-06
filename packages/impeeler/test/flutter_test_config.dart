import 'dart:async';

import 'package:impeeler/impeeler.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpeelerBinding.ensureInitialized();
  await testMain();
}
