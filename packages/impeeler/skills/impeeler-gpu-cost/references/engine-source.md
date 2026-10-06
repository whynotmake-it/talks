# Looking up the engine source

The model ports Impeller's decisions from one Flutter release
(`pinnedFlutterVersion` in `lib/src/engine/revision.dart`). Since Flutter
3.29 the engine lives in the framework repository, so the Flutter SDK you
already have contains the source that decides your passes:

```sh
FLUTTER_ROOT="$(dirname "$(dirname "$(command -v flutter)")")"  # with fvm: .fvm/flutter_sdk
ENGINE="$FLUTTER_ROOT/engine/src/flutter"
```

Online, the same files are at
`https://github.com/flutter/flutter/blob/<version>/engine/src/flutter/<path>`.

## Where each decision lives

| Question | File (relative to `$ENGINE`) |
| --- | --- |
| When does a saveLayer get a pass; the opacity peephole; backdrop flips; BackdropGroup sharing; advanced blends | `impeller/display_list/canvas.cc` |
| Which layers and paints become saveLayers; overlap and opacity bookkeeping | `display_list/dl_builder.cc`, `display_list/dl_builder.h` |
| Layer tree to display list (OpacityLayer, BackdropFilterLayer, ClipShapeLayer) | `flow/layers/*.cc` |
| Gaussian blur passes, sizes and downsampling | `impeller/entity/contents/filters/gaussian_blur_filter_contents.cc` |
| Blend filters without framebuffer fetch | `impeller/entity/contents/filters/blend_filter_contents.cc` |
| Framebuffer-fetch blends | `impeller/entity/contents/framebuffer_blend_contents.cc` |
| Offscreen texture formats, MSAA, storage modes | `impeller/renderer/render_target.cc`, `impeller/renderer/backend/metal/allocator_mtl.mm`, `impeller/core/formats.h` |
| Device capabilities (framebuffer fetch, GLES fallback) | `impeller/renderer/backend/vulkan/capabilities_vk.cc`, `impeller/renderer/backend/vulkan/driver_info_vk.cc`, `impeller/renderer/backend/gles/capabilities_gles.cc` |
| iOS pixel format and wide gamut | `shell/platform/darwin/ios/framework/Source/FlutterView.mm`, `shell/platform/darwin/ios/ios_surface_metal_impeller.mm` |

Search the package for a quote to find the Dart code that mirrors it: every
engine decision is quoted next to its port in a fenced block that starts with
```` ```engine <path> ````:

```sh
grep -rn '```engine impeller/display_list/canvas.cc' lib/
```

## When your SDK is not the pinned one

From the package directory:

```sh
dart run tool/engine_refs.dart                        # are all quotes still in the pinned SDK?
dart run tool/engine_refs.dart --diff-to <your tag>   # which quoted files changed, and which quotes vanished
```

A vanished quote marks engine logic the model no longer matches. Read the
changed file at your version before trusting an estimate that depends on it.
