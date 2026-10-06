# Reducing Impeller GPU cost

Each pattern names the widget, the pass it removes, and the engine rule
behind it (paths are relative to `engine/src/flutter/` in the Flutter SDK;
see [engine-source.md](engine-source.md)). Rerun the estimate after every
change: the report shows whether the rule applied to your tree.

## Backdrop filters (`BackdropFilter`, frosted glass, Cupertino dialogs and bars)

A backdrop filter must read what was drawn before it, so Impeller ends the
current pass, stores it, runs the filter (a blur is three passes), and
continues in a new pass that redraws the stored texture. The whole frame
starts offscreen and is copied to the screen at the end.
(`impeller/display_list/canvas.cc`, `Canvas::SaveLayer` with a
`backdrop_filter`.)

- **Bound the blur with a clip.** Wrap the `BackdropFilter` in a
  `ClipRect`/`ClipRRect` of the area that shows it. The blur input is cut to
  the clip (`coverage_hint`), so a dialog-sized clip blurs a dialog-sized
  region instead of the screen.
- **Group backdrops that share a filter.** Several `BackdropFilter`s with the
  same filter under one `BackdropGroup`, each built with
  `BackdropFilter.grouped`, run the filter once for the group; members draw
  the shared snapshot without a pass of their own
  (`backdrop_data->all_filters_equal` in `canvas.cc`). Measured on macOS
  Metal: two backdrops cost 5 + 6 passes, the same two grouped cost 2 + 3.
- **Drop the backdrop when nothing behind it moves.** Over static content, a
  pre-blurred image or a translucent solid color gives the same look with no
  passes. Cupertino navigation bars blur only while their background is
  translucent: inside a `CupertinoPageScaffold` the blur is off until
  content scrolls under the bar (`automaticBackgroundVisibility`), and
  `enableBackgroundFilterBlur: false` turns it off for good.
- **Count backdrops per frame.** Each additional backdrop ends the pass again
  and adds its own blur. Without framebuffer fetch (Pixel 10, OpenGL ES) the
  frame also cannot continue on screen after the last backdrop, so it pays
  one more full-screen pass for the final copy (measured: one backdrop 6
  passes on macOS and 7 on a Pixel 10; two backdrops 11 and 12).

## Opacity (`Opacity`, `FadeTransition`, `AnimatedOpacity`)

Opacity needs an offscreen layer unless it can be distributed to the
children's paints: the "opacity peephole"
(`display_list/dl_builder.cc` `can_distribute_opacity`,
`impeller/display_list/canvas.cc` `Paint::CanApplyOpacityPeephole`).

- **Fade one non-overlapping thing.** The peephole applies when the children
  do not overlap each other and none uses a blend mode, image filter, color
  filter or mask blur. A fading icon or text run costs nothing; a fading card
  with a shadow under its content needs a layer.
- **Put alpha in the paint** when you own the drawing: a color with alpha,
  `Image(opacity:)`, or `Text` with a translucent color.
- **Fades cost only mid-animation.** `Opacity(opacity: 0)` paints nothing,
  and an `OpacityLayer` at full opacity adds no layer
  (`flow/layers/layer_state_stack.cc` applies opacity only below 1). A fade
  that never finishes (a pulsing badge) pays the layer on every frame; see
  `impeeler-frame-demand`.

## Layers (`saveLayer`)

- **`Clip.antiAliasWithSaveLayer` opens a layer.** Use `Clip.antiAlias` or
  `Clip.hardEdge` unless the edge bleeding is visible.
- **`ShaderMask` is always a layer**, sized to the masked child. Keep the
  child small.
- **Custom painters:** give `canvas.saveLayer` tight bounds, or avoid it.
  Unbounded content (a paint that covers everything) makes the layer full
  screen and blocks the opacity peephole.

## Blend modes

Modes after `BlendMode.modulate` (screen, overlay, darken, lighten,
colorDodge, colorBurn, hardLight, softLight, difference, exclusion, multiply,
hue, saturation, color, luminosity) are *advanced blends*
(`impeller/entity/entity.h` `kLastPipelineBlendMode`).

- With framebuffer fetch (iPhone, most Android Vulkan GPUs) the blend first
  snapshots its source into a texture: one extra pass of the source's size.
- Without it (Pixel 10, OpenGL ES, iOS Simulator) the blend also ends the
  current pass and blends in an extra pass: the frame goes offscreen. A
  full-screen `saturation` blend costs 5 full-screen passes on a Pixel 10.
- Bake the effect into an asset when the content is static.

## Shadows and blurs on shapes

- **`BoxShadow`, `PhysicalModel` elevation, `Material` shadows are cheap.**
  A mask blur on a filled rect, rounded rect, oval, circle or path without a
  shader takes Impeller's analytic shadow path: no passes
  (`impeller/display_list/canvas.cc`, the fast paths before
  `CreateMaskBlur`).
- Mask blurs on images, text, strokes or shaded paints run a real blur.
- `ImageFiltered(ImageFilter.blur)` over a subtree is a layer plus three blur
  passes. A blurred `BoxShadow` behind the subtree is usually the cheaper way
  to get a glow.
- A blur with both sigmas below 1/4096 is dropped by the engine: a
  `BackdropFilter` then becomes a plain layer (free when the opacity
  peephole applies; measured on both devices). Animate a fading blur to
  exactly 0, not to a tiny value
  (`display_list/effects/image_filters/dl_blur_image_filter.cc`).

## How often it costs

A frame's passes are paid every time it renders. A screen that repaints
every vsync while it looks still (a caret, a looping animation) multiplies
the cost by 60–120 per second: find those with the
`impeeler-frame-demand` skill.
