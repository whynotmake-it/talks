import 'dart:async';

import 'package:impeller_model/impeller_model.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpellerModelBinding.ensureInitialized();
  await testMain();
}
