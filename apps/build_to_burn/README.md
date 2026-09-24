# build_to_burn

Fluttercon 2026 talk: following one Flutter frame from build to burn.

Runs on motor 2.0 from the rivership PR stack. The git ref is pinned in this
package's `pubspec.yaml` and in the `dependency_overrides` of the root
`pubspec.yaml`; bump both together.

```sh
flutter run -d macos             # the presentation target (Impeller)
flutter run -d chrome            # quick look in the browser
flutter test                     # every slide lays out with the real fonts
```

Navigate with the arrow keys. Each slide has a route (`/#/hook`,
`/#/frame-pipeline`, …) for jumping straight to it.

- `lib/design/`: tokens from motor's example gallery (`style.dart`), the
  flutter_deck theme, the shared slide chrome, and motor-driven helpers.
- `lib/templates/`: slide layouts.
- `lib/slides/`: the slides, in the order `main.dart` lists them.
