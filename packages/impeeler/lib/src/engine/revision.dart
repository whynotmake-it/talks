/// The Flutter release whose engine and framework source every port in
/// `lib/src/engine/` (and every `framework` quote in `lib/src/capture/`) was
/// read from.
///
/// Every quote fenced as ```` ```engine <path> ```` or
/// ```` ```framework <path> ```` in this package is checked against this
/// checkout by `dart run tool/engine_refs.dart`. Bump these together with a
/// clean `engine_refs.dart` run against the new SDK (see MAINTAINING.md).
const String pinnedFlutterVersion = '3.47.1';

/// `bin/internal/engine.version` of [pinnedFlutterVersion].
const String pinnedEngineRevision = '5d531788691ec3404cac0cee66ead4007b177363';
