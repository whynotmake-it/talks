## 0.1.0-dev.2

- Correct bundled-skill installation instructions to use
  `dart run skills@ get -p impeeler`, following Dart's package-skills guidance.
- Remove the unnecessary Node.js/npm requirement and hard-coded pub-cache
  paths from the README.

## 0.1.0-dev.1

- Add homepage and repository links to package metadata.
- Add the MIT license and retain Flutter's BSD-3-Clause license and notices.
- Move agent skills near the top of the README and document installation
  from the pub package.
- Make `impeeler-gpu-cost` the entry skill and clarify guidance for blur,
  opacity, edge fades, and hidden animations.

## 0.1.0-dev.0

- Initial development release: estimates Impeller render passes and memory
  traffic for a Flutter screen, from a widget test.
- Measures idle frame demand and attributes frame requests and tickers to
  their widgets.
- Device presets (iPhone, Pixel, ...) plus JSON/HTML reports and optional
  screenshots.
- Engine model pinned to Flutter 3.47.1; estimates are not measured GPU
  time or energy.
