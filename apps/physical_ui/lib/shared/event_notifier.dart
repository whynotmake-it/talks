import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that exposes its [notifyListeners] publicly.
class EventNotifier extends ChangeNotifier {
  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}
