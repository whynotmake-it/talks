/// Names the widget behind a layer or ticker, and the line in app code
/// that created it.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A widget, described for a report.
class WidgetOrigin {
  WidgetOrigin({required this.widget, required this.path, this.location});

  /// The widget's type, e.g. `BackdropFilter`.
  final String widget;

  /// The element and its ancestors, nearest first, up to and including
  /// the first widget created in app code (or the 6 nearest if none is).
  final List<String> path;

  /// `lib/screens/home.dart:42`: where the nearest app-code widget on
  /// [path] was created. Null without `--track-widget-creation` (on by
  /// default in `flutter test`) or when no ancestor is app code.
  final String? location;

  /// `BackdropFilter (lib/screens/home.dart:42)`.
  String get label => location == null ? widget : '$widget ($location)';

  Map<String, Object?> toJson() => {
    'widget': widget,
    'path': path,
    if (location != null) 'location': location,
  };
}

/// Describes [element] and finds the nearest app-code creation location,
/// searching up to [maxDepth] ancestors.
WidgetOrigin describeElement(Element element, {int maxDepth = 80}) {
  final path = <String>[_name(element.widget)];
  var location = _appCreationLocation(element);
  if (location == null) {
    var depth = 0;
    element.visitAncestorElements((ancestor) {
      depth++;
      path.add(_name(ancestor.widget));
      location = _appCreationLocation(ancestor);
      return location == null && depth < maxDepth;
    });
    if (location == null) {
      path.removeRange(math.min(path.length, 6), path.length);
    }
  }
  return WidgetOrigin(
    widget: _name(element.widget),
    path: path,
    location: location,
  );
}

/// The widget type without key or generic noise.
String _name(Widget w) => w.runtimeType.toString();

/// A layer's creator, when it is the usual `DebugCreator(element)`.
///
/// ```framework flutter/lib/src/widgets/framework.dart
///       renderObject.debugCreator = DebugCreator(this);
/// ```
/// ```framework flutter/lib/src/rendering/object.dart
///         child._layerHandle.layer!.debugCreator = child.debugCreator ?? child;
/// ```
WidgetOrigin? describeCreator(Object? debugCreator) {
  if (debugCreator is DebugCreator) {
    return describeElement(debugCreator.element);
  }
  return null;
}

/// The widget's creation location if it was created in app code.
///
/// ```framework flutter/lib/src/widgets/widget_inspector.dart
///     final _Location? creationLocation = _getCreationLocation(value);
///     if (creationLocation != null) {
///       if (fullDetails) {
///         result['locationId'] = _toLocationId(creationLocation);
///         result['creationLocation'] = creationLocation.toJsonMap();
///       }
/// ```
String? _appCreationLocation(Element element) {
  final Map<String, Object?> props;
  try {
    props = InspectorSerializationDelegate(
      service: WidgetInspectorService.instance,
    ).additionalNodeProperties(element.toDiagnosticsNode());
  } on Object {
    return null;
  }
  final loc = props['creationLocation'];
  if (loc is! Map) {
    return null;
  }
  final file = '${loc['file']}';
  if (file.contains('/packages/flutter/lib/') ||
      file.contains('/.pub-cache/') ||
      file.contains('/packages/flutter_test/')) {
    return null;
  }
  return '${_shortPath(file)}:${loc['line']}';
}

String _shortPath(String file) {
  final path = file.replaceFirst('file://', '');
  for (final marker in ['/lib/', '/test/', '/integration_test/']) {
    final i = path.lastIndexOf(marker);
    if (i >= 0) {
      return path.substring(i + 1);
    }
  }
  return path;
}
