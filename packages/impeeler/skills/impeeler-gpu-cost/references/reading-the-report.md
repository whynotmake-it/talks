# Reading an impeeler report

## Units

- **Render passes.** Encoded render passes in one frame. On Metal the final
  copy of an offscreen frame is a blit, not a render pass (`blitToOnscreen`).
  Each Gaussian blur adds three passes.
- **Screen-equivalents** (`traffic.extraScreenEquivalents`) and
  **× a plain frame** (`traffic.relativeToPlainFrame`). Bytes moved by pass
  ends and readbacks, divided by one full-screen write. A full-screen
  offscreen pass costs 2.0 (stored once, read once). Independent of pixel
  format (every texture of a frame shares one), but not of the device: screen
  size changes the blur and layer sizes relative to the screen, and devices
  without framebuffer fetch add passes. Compare it per device.
- **Bytes** (`traffic.extraBytes`, "MB beyond the screen write"). Nominal:
  `width × height × bytes per pixel` per write and per read. An upper bound,
  not a bandwidth measurement:
  - iOS devices render offscreen textures in `BGRA10_XR`, **8 B/px**
    (wide gamut is on by default). The iOS Simulator renders `BGRA8`, Android
    Vulkan `RGBA8`: 4 B/px.
  - MSAA samples never reach memory. Impeller's 4× MSAA attachments are
    transient (memoryless on Apple GPUs) and only the 1-sample resolve texture
    is stored, so the model counts 1 sample.
  - A15/M2 and newer Apple GPUs store these textures with lossy compression
    (about half the nominal size); most GPUs also compress losslessly. The
    report notes it where it applies.
  - Partial repaint is not modeled: iOS may redraw only a damaged region of
    the screen. The estimate is the full frame.
- **Frame demand**: see the `impeeler-frame-demand` skill.

## Pass roles

| Role | Title in the report | Why it exists |
| --- | --- | --- |
| `onscreenRoot` | Frame | The frame drawn straight into the screen. The only pass of a plain frame. |
| `offscreenRoot` | Offscreen frame | Something reads back what was drawn (backdrop filter, or advanced blend without framebuffer fetch), so the frame starts offscreen. |
| `restartAfterFlip` | Restarted pass | The pass was ended so a filter could read it; drawing continues in a new pass that first redraws the stored texture. |
| `onscreenAfterFlip` | Frame (continued on screen) | After the last backdrop, drawing continues in the screen surface (framebuffer-fetch devices). |
| `saveLayer` | Layer | An offscreen layer: `saveLayer`, `Opacity` over overlapping children, `ShaderMask`, a clip with `Clip.antiAliasWithSaveLayer`, a backdrop's enclosing layer. |
| `blurDownsample`, `blurY`, `blurX` | Blur: downsample / vertical / horizontal | The three passes of a Gaussian blur, at reduced resolution. |
| `filterInputSnapshot` | Filter input | A filter's input rendered into a texture first (a color filter feeding a blur, as in `CupertinoAlertDialog`). |
| `blendSourceSnapshot` | Blend source | An advanced blend mode renders its source into a texture first. |
| `advancedBlend` | Emulated blend | Without framebuffer fetch, an advanced blend reads the stored backdrop in an extra pass. |
| `morphology` | Dilate/erode | One direction of `ImageFilter.dilate`/`erode`. |
| `filter` | Filter | A filter the model does not port in detail (`approximate`). |
| `copyToOnscreen` | Copy to screen | The offscreen frame copied to the screen with a render pass (Vulkan, GLES). |
| `blitToOnscreen` | Blit to screen | The same copy as a blit (Metal). |

## Fields worth reading in `ModelPass`

- `cause`: the widget or op that opened the pass.
- `endedBy`: what forced the pass to end early (a flip), e.g. `BackdropFilter
  (lib/x.dart:12)`.
- `chargedTo`: the cost center the pass counts against.
- `engineLabel` / `commandBufferLabel`: the label Impeller gives it in a GPU
  capture (debug and profile builds only; on Vulkan only with validation
  layers).
- `approximate`: the shape is a guess, not a port.

## Device classes

| Preset | Backend | Framebuffer fetch | B/px |
| --- | --- | --- | --- |
| `iPhone16`, `iPhone16Pro`, `iPhone16ProMax`, `iPhoneSE`, `iPadPro13` | Metal | yes | 8 |
| `iosSimulator` | Metal | no | 4 |
| `pixel9`, `galaxyS25` | Vulkan | yes | 4 |
| `pixel10` (PowerVR) | Vulkan | no | 4 |
| `olderAndroidGles` (Adreno 650 and older) | OpenGL ES | no | 4 |

Framebuffer fetch decides how many extra passes advanced blends and backdrop
filters cost; it is the biggest difference between device classes.
