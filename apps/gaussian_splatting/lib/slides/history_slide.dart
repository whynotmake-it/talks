
import 'package:flutter/material.dart';
import 'package:flutter_gaussian_splatter/widgets/gaussian_splatter_widget.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// Image based rendering
/// -

// Section 2: The NeRF Era: The Neural Revolution
// This section marks the paradigm shift towards using neural networks to learn a scene representation. The key concept is moving from explicit geometry (points, meshes) to a continuous, implicit function that a network learns.

// Image 2: A Visualization of a Neural Radiance Field

// Description: A semi-abstract image depicting a 3D object (e.g., the classic Lego bulldozer) at the center. From one side, camera rays are shown entering a glowing, ethereal "cloud" or "field" that surrounds the object. On the other side, a photorealistic 2D image is shown emerging from the field.
// Why it works: This visual explains the "magic" of NeRF without getting overly technical. It illustrates:
// Implicit Representation: The scene is not a collection of points, but an abstract, learned "field."
// Volumetric Rendering: The rays passing through the field are key to how the image is formed.
// The "Black Box": It conveys the idea that a neural network is learning a complex function that turns 5D coordinates (location + view direction) into color and density.
// Section 3: The GS Era: Real-Time & Explicit
// This section represents the current state-of-the-art, which takes the quality of NeRF and makes it incredibly fast by returning to an explicit, but more powerful, representation. The core concept is representing the scene with millions of tiny, learnable particles.

// Image 3: A Scene Deconstructed into 3D Gaussians

// Description: A stunning, high-fidelity image that is split down the middle. One half shows the final, photorealistic rendered scene. The other half "peels back" that render to reveal the underlying representation: millions of colorful, semi-transparent, overlapping ellipsoids (the "splats" or Gaussians).
// Why it works: This is the most powerful image for a talk about Gaussian Splatting. It demonstrates:
// Explicit Representation: You can see the individual components that make up the scene, contrasting directly with NeRF's implicit "cloud."
// From Primitives to Photorealism: It directly connects the underlying geometric primitives (the Gaussians) to the final, beautiful image.
// State-of-the-Art: The visual quality is top-tier, and the deconstruction provides the "aha!" moment for the audience, explaining how this new method works.

// Fig. 2: An overview of our neural radiance field scene representation and diﬀer-
// entiable rendering procedure. We synthesize images by sampling 5D coordinates
// (location and viewing direction) along camera rays (a), feeding those locations
// into an MLP to produce a color and volume density (b), and using volume ren-
// dering techniques to composite these values into an image (c). This rendering
// function is diﬀerentiable, so we can optimize our scene representation by mini-
// mizing the residual between synthesized and ground truth observed images (d).

// -beats jpeg compression
// -slow

class HistorySlide extends FlutterDeckSlideWidget {
  const HistorySlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history',
          steps: 5,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: Stack(
          children: [
            // Title
            // Positioned(
            //   top: 50,
            //   left: 100,
            //   right: 100,
            //   child: Center(
            //     child: DefaultTextStyle.merge(
            //       style: theme.textTheme.display.copyWith(
            //         color: colorScheme.onPrimaryContainer,
            //         letterSpacing: -5,
            //         height: 1,
            //       ),
            //       child: const Text(
            //         'Evolution of Novel View Synthesis',
            //         textAlign: TextAlign.center,
            //       ),
            //     ),
            //   ),
            // ),

            // Citations at bottom
            Positioned(
              bottom: 20,
              left: 50,
              right: 50,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reche-Martinez, A., Martin, I., & Drettakis, G. (2004). Volumetric reconstruction and interactive rendering of trees from photographs. In ACM SIGGRAPH 2004 Papers (pp. 720-727).',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mildenhall, B., Srinivasan, P. P., Tancik, M., Barron, J. T., Ramamoorthi, R., & Ng, R. (2021). Nerf: Representing scenes as neural radiance fields for view synthesis. Communications of the ACM, 65(1), 99-106.',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kerbl, B., Kopanas, G., Leimkühler, T., & Drettakis, G. (2023). 3D Gaussian splatting for real-time radiance field rendering. ACM Trans. Graph., 42(4), 139-1.',
                    ),
                  ],
                ),
              ),
            ),

            // Three columns
            Positioned(
              top: 32,
              left: 32,
              right: 32,
              bottom: 100,
              child: FlutterDeckSlideStepsBuilder(
                builder: (context, stepNumber) {
                  return Stack(
                    children: [
                      Row(
                        children: [
                          // Column 1: 2004 IBL Paper
                          Expanded(
                            child: _AnimatedColumn(
                              visible: stepNumber >= 2,
                              stagger: 0,
                              title: '2004\nImage-Based Rendering',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black,
                                ),
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Video(
                                      assetKey: 'assets/ibl-2004.mp4',
                                      play: stepNumber >= 2,
                                      loop: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 40),

                          // Column 2: 2021 NeRF
                          Expanded(
                            child: _AnimatedColumn(
                              visible: stepNumber >= 4,
                              stagger: 1,
                              title: '2021\nNeural Radiance Fields',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1008 / 768,
                                      child: Video(
                                        assetKey: 'assets/nerf-2021.mp4',
                                        play: stepNumber >= 3,
                                        loop: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 40),

                          // Column 3: 2023 Gaussian Splatting
                          Expanded(
                            child: _AnimatedColumn(
                              visible: stepNumber >= 5,
                              stagger: 2,
                              title: '2023\n3D Gaussian Splatting',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GaussianSplatterWidget(
                                    assetPath: 'assets/toycar.ply',
                                    enableProfiling: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Full screen NeRF overlay (step 3)
                      IgnorePointer(
                        child: Positioned.fill(
                          child: Center(
                            child: SingleMotionBuilder(
                              value: stepNumber == 3 ? 1.0 : 0.0,
                              motion: CupertinoMotion.bouncy(
                                duration: const Duration(milliseconds: 800),
                              ),
                              child: Image.asset(
                                'assets/nerf.png',
                                fit: BoxFit.contain,
                              ),
                              builder: (context, value, child) => SizedBox.expand(
                                child: ColoredBox(
                                  color: Theme.of(
                                    context,
                                  ).cardColor.withValues(alpha: value - 0.1),
                                  child: Transform.scale(
                                    scale: 0.7 + (0.3 * value),
                                    child: Opacity(
                                      opacity: value.clamp(0, 1),
                                      child: child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedColumn extends StatelessWidget {
  const _AnimatedColumn({
    required this.visible,
    required this.stagger,
    required this.title,
    required this.child,
  });

  final bool visible;
  final int stagger;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 800) +
          Duration(milliseconds: 150 * stagger),
    );

    return MotionBuilder(
      value: visible ? Offset.zero : const Offset(0, 100),
      motion: motion,
      converter: OffsetMotionConverter(),
      builder: (context, value, child) => Transform.translate(
        offset: value,
        child: SingleMotionBuilder(
          value: visible ? 1.0 : 0.0,
          motion: motion,
          child: child,
          builder: (context, value, child) => Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value.clamp(0, 1),
              child: child,
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }
}
