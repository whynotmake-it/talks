import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RenderingSlide3 extends FlutterDeckSlideWidget {
  const RenderingSlide3({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/rendering-3',
          // steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);

    return ContentSlideTemplate(
      title: const Text(
        'Render Journey',
        textAlign: TextAlign.left,
      ),
      mainContent: FlutterDeckCodeHighlight(
        textStyle: theme.textTheme.bodyMedium,
        code: '''
# Main thread
sorter.init(onComplete: (idx) => uploadOrderTexture(idx))
sorter.run(viewProj, splatBuffer, splatCount)

# Sort isolate
onMessage(viewProj, buffer, n):
  pos = reinterpretF32(buffer)          # x,y,z per splat
  idx = counting/radix_sort(d,          # run bucket sort
        buckets=65536, order=back_to_front,
        quantize=true, reuse_arrays=true)
  sendToMain(idx)
  ''',
        fileName: 'depth_sorter.dart',
      ),

      secondaryContent: Image.asset(
        'assets/radix_sort.png',
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
