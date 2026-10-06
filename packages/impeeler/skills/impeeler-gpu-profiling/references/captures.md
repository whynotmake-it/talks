# Reading Impeller in a GPU capture

What engine 3.47.1 labels its GPU work, and how big its textures are. Used
by step 5 of the `impeeler-gpu-profiling` skill.

## Labels

Instruments prefixes encoder labels
with the encoder type (`RenderPass & EntityPass Render Pass`); gpudebug appends
` (2)`, ` (3)` to repeated labels.

| Label | Kind | Meaning |
| --- | --- | --- |
| `EntityPass Render Pass` | render pass | Any Impeller EntityPass pass: the root pass, a saveLayer subpass, or the root restarting after a backdrop filter flip. |
| `EntityPass Command Buffer` | command buffer | Holds EntityPass render passes. |
| `Gaussian Blur Filter` | render pass | A Gaussian blur: three passes (downsample, Y, X), no MSAA. |
| `GaussianBlur` | render pass | Snapshot of a blur input that is not yet a texture, e.g. a color filter composed into a backdrop blur (`CupertinoAlertDialog`). |
| `FramebufferBlendContents Snapshot` | render pass | With framebuffer fetch: the source of an advanced blend rendered into a texture. |
| `AdvancedBlend(Src)` | render pass | Without framebuffer fetch: the same source snapshot, before `Advanced Blend Filter`. |
| `Advanced Blend Filter`, `Pipeline Blend Filter`, `Directional Morphology Filter` | render pass | Other filter passes. |
| `EntityPass Root Command Buffer` | command buffer (Metal) | Blit copying an offscreen root to the onscreen texture. |
| `EntityPass Root Render Pass` | render pass (other backends) | The same copy as a render pass. |
| `EntityPass Color Texture`, `EntityPass Color Texture (Multisample)` | texture | Offscreen color attachment and its MSAA counterpart. |
| `EntityPass Depth+Stencil Texture` | texture | Offscreen depth/stencil attachment. |

On Metal with Apple GPUs, the MSAA color and depth/stencil attachments are memoryless
(`StorageMode::kDeviceTransient`) and the color store action is multisample
resolve, so only the 1-sample resolve texture reaches memory.

## Bytes per pixel

| Target | Format | B/px |
| --- | --- | --- |
| iOS device (wide gamut, `FLTEnableWideGamut` default YES) | `BGRA10_XR` | 8 |
| macOS on a wide-gamut display | `BGRA10_XR` | 8 |
| iOS Simulator | `BGRA8Unorm` | 4 |
| Android Vulkan | `RGBA8` | 4 |

A full-screen offscreen pass costs `width x height x B/px` per write or read of
its resolve texture. The `allocatedSize` a capture reports can be lower because
Apple GPUs compress these textures (see
[apple.md](apple.md#reading-a-metal-capture)); use dimensions and
format for traffic, not `allocatedSize`.
