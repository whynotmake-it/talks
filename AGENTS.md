# Agent notes

## Rules

- Do NOT write tests for slides, ever. No new test files, no new test cases,
  no throwaway test files for rendering or screenshots. Check slides
  visually in the running app instead.

## Running

- Flutter comes from fvm (`.fvm/flutter_sdk`). Run apps from their directory,
  e.g. `cd apps/build_to_burn && flutter run -d macos`.
- `flutter analyze` must stay clean.
