# Validation: macos

Render passes per frame, by Impeller label: impeller_model prediction vs. Metal System Trace of the validation app (`dart run tool/validate.dart macos`).

| Scene | Predicted | Measured | Blit predicted / measured | Frames like this | |
|---|---|---|---|---|---|
| `plain` | 1× EntityPass Render Pass | 1× EntityPass Render Pass | no / no | 436/456 | ✓ |
| `opacity_single` | 1× EntityPass Render Pass | 1× EntityPass Render Pass | no / no | 442/462 | ✓ |
| `opacity_overlap` | 2× EntityPass Render Pass | 2× EntityPass Render Pass | no / no | 441/461 | ✓ |
| `clip_savelayer` | 2× EntityPass Render Pass | 2× EntityPass Render Pass | no / no | 441/462 | ✓ |
| `backdrop_blur` | 3× EntityPass Render Pass<br>3× Gaussian Blur Filter | 3× EntityPass Render Pass<br>3× Gaussian Blur Filter | no / no | 442/462 | ✓ |
| `two_backdrops` | 5× EntityPass Render Pass<br>6× Gaussian Blur Filter | 5× EntityPass Render Pass<br>6× Gaussian Blur Filter | no / no | 441/461 | ✓ |
| `backdrop_group` | 2× EntityPass Render Pass<br>3× Gaussian Blur Filter | 2× EntityPass Render Pass<br>3× Gaussian Blur Filter | no / no | 443/463 | ✓ |
| `image_filtered_blur` | 2× EntityPass Render Pass<br>3× Gaussian Blur Filter | 2× EntityPass Render Pass<br>3× Gaussian Blur Filter | no / no | 440/460 | ✓ |
| `box_shadow` | 1× EntityPass Render Pass | 1× EntityPass Render Pass | no / no | 440/460 | ✓ |
| `saturation_blend` | 1× FramebufferBlendContents Snapshot<br>1× EntityPass Render Pass | 1× EntityPass Render Pass<br>1× FramebufferBlendContents Snapshot | no / no | 441/461 | ✓ |
| `savelayer_blend` | 2× EntityPass Render Pass | 2× EntityPass Render Pass | no / no | 440/460 | ✓ |
| `cupertino_alert` | 3× EntityPass Render Pass<br>1× GaussianBlur<br>3× Gaussian Blur Filter | 3× EntityPass Render Pass<br>1× GaussianBlur<br>3× Gaussian Blur Filter | no / no | 442/462 | ✓ |
| `backdrop_sigma0` | 1× EntityPass Render Pass | 1× EntityPass Render Pass | no / no | 390/410 | ✓ |
| `backdrop_in_layer` | 4× EntityPass Render Pass<br>3× Gaussian Blur Filter | 4× EntityPass Render Pass<br>3× Gaussian Blur Filter | no / no | 437/457 | ✓ |

14 of 14 scenes match.
