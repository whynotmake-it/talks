/// Finds the tickers that live in the widget tree and who owns them.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'creation_location.dart';

/// A ticker owned by a `State` (through `SingleTickerProviderStateMixin`,
/// `TickerProviderStateMixin`, or any mixin that reports it the same way).
class TickerInfo {
  TickerInfo({
    required this.owner,
    required this.ownerPath,
    required this.isActive,
    required this.isMuted,
    required this.tickerType,
    this.ownerLocation,
  });

  /// The widget whose State owns the ticker, e.g. `EditableText`.
  final String owner;

  /// The nearest ancestors, nearest first, ending at the first widget
  /// created in app code when one is found.
  final List<String> ownerPath;

  /// Where the closest app-code ancestor widget was created
  /// (`lib/screens/home.dart:42`), when widget creation is tracked.
  final String? ownerLocation;

  /// `Ticker.isActive`: started and not stopped. An active, unmuted ticker
  /// requests every frame.
  final bool isActive;

  /// `Ticker.muted`, e.g. under `TickerMode(enabled: false)`.
  final bool isMuted;

  /// `Ticker` or a subclass such as `FixedTicker` (which ticks at a fixed
  /// rate instead of every vsync).
  final String tickerType;

  bool get requestsFrames => isActive && !isMuted;

  Map<String, Object?> toJson() => {
    'owner': owner,
    'ownerPath': ownerPath,
    if (ownerLocation != null) 'ownerLocation': ownerLocation,
    'active': isActive,
    'muted': isMuted,
    'type': tickerType,
  };
}

/// Lists every ticker reported by a State's diagnostics.
///
/// The ticker provider mixins expose their tickers as diagnostics
/// properties, which is public API:
///
/// ```framework flutter/lib/src/widgets/ticker_provider.dart
///     properties.add(
///       DiagnosticsProperty<Ticker>(
///         'ticker',
///         _ticker,
///         description: tickerDescription,
/// ```
/// ```framework flutter/lib/src/widgets/ticker_provider.dart
///     properties.add(
///       DiagnosticsProperty<Set<Ticker>>(
///         'tickers',
///         _tickers,
/// ```
///
/// Tickers created outside a State (e.g. `Ticker(...)` in a render object)
/// are not found here; their frame requests still show up in
/// `FrameDemand.requests`.
List<TickerInfo> findTickers() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) {
    return const [];
  }
  final result = <TickerInfo>[];
  void visit(Element element) {
    if (element is StatefulElement) {
      for (final ticker in _tickersOf(element.state)) {
        result.add(_describe(element, ticker));
      }
    }
    element.visitChildren(visit);
  }

  root.visitChildren(visit);
  return result;
}

Iterable<Ticker> _tickersOf(State state) sync* {
  final List<DiagnosticsNode> properties;
  try {
    properties = state.toDiagnosticsNode().getProperties();
  } on Object {
    return;
  }
  for (final p in properties) {
    final value = p.value;
    if (p.name == 'ticker' && value is Ticker) {
      yield value;
    } else if (p.name == 'tickers' && value is Iterable) {
      yield* value.whereType<Ticker>();
    }
  }
}

TickerInfo _describe(StatefulElement element, Ticker ticker) {
  final origin = describeElement(element);
  return TickerInfo(
    owner: origin.widget,
    ownerPath: origin.path,
    ownerLocation: origin.location,
    isActive: ticker.isActive,
    isMuted: ticker.muted,
    tickerType: ticker.runtimeType.toString(),
  );
}
