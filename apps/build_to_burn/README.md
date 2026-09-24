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

The structure follows `apps/gaussian_splatting`, last year's lightning talk:

- `lib/slides/`: one `FlutterDeckSlideWidget` per file, each with its own
  route and speaker notes. `main.dart` lists them in order.
- `lib/shared/`: tokens from motor's example gallery (`style.dart`), the
  flutter_deck theme, the slide chrome and templates, and motor-driven
  helpers.

Start a slide's speaker notes with `timSlideNotesHeader` or
`jesperSlideNotesHeader` from `package:wnma_talk/slide_number.dart` to show
who is speaking in the top bar.
