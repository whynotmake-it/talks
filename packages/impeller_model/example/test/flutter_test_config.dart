import 'dart:async';

import 'package:impeller_model/impeller_model.dart';

/// Installs the binding that records every picture's draw calls. It must be
/// in place before the first `testWidgets`, so it lives here rather than in
/// `main()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpellerModelBinding.ensureInitialized();
  await testMain();
}
