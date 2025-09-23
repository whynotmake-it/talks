import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:wnma_talk/code_highlight.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HeroineDemoSlide extends FlutterDeckSlideWidget {
  const HeroineDemoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Heroine Demo',
          route: '/heroine-demo',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  static const _heroinePseudoCode = '''
// 1. Setup HeroineController in your app
MaterialApp(
  navigatorObservers: [HeroineController()],
)

// 2. Hero transitions with shuttle builders
Heroine(
  tag: index,
  motion: CupertinoMotion.smooth(),
  flightShuttleBuilder: const FadeShuttleBuilder()
    .chain(const FlipShuttleBuilder()),
  child: Cover(index: index),
);

// 3. Drag-to-dismiss functionality
DragDismissable(
  child: Heroine(
    tag: index,
    child: MyWidget(),
  ),
)

// 4. React to dismiss gestures
ReactToHeroineDismiss(
  builder: (context, progress, offset, child) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: (1-progress) * 20),
      child: child,
    );
  },
);
''';

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Heroine Demo'),
      mainContent: const Row(
        children: [
          // Left Column: Interactive Demo
          Expanded(
            child: Center(
              child: HeroineDeviceDemo(),
            ),
          ),

          // Right Column: Code Example
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 32),
              child: CodeHighlight(
                filename: 'heroine_example.dart',
                code: _heroinePseudoCode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroineDeviceDemo extends StatelessWidget {
  const HeroineDeviceDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: DeviceFrame(
        device: Devices.ios.iPhone16,
        screen: CupertinoApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [HeroineController()],
          home: const ImageGridExample(),
        ),
      ),
    );
  }
}

// Global motion notifiers for dynamic configuration
final springNotifier = ValueNotifier<Motion>(CupertinoMotion.smooth());
final flightShuttleNotifier = ValueNotifier<HeroineShuttleBuilder?>(
  const FadeShuttleBuilder().chain(
    const FlipShuttleBuilder(
      axis: Axis.vertical,
      halfFlips: 1,
    ),
  ),
);
final detailsPageAspectRatio = ValueNotifier<double>(1);

// Custom route with HeroinePageRouteMixin
class MyCustomRoute<T> extends PageRoute<T> with HeroinePageRouteMixin {
  MyCustomRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.fullscreenDialog = false,
    super.allowSnapshotting = true,
    this.title,
  });

  final WidgetBuilder builder;
  final String? title;

  @override
  final bool maintainState;

  @override
  final bool fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final result = builder(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: result,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class ImageGridExample extends StatelessWidget {
  const ImageGridExample({super.key});

  static const name = 'Image Grid';
  static const path = 'image-grid';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable:
          ModalRoute.of(context)?.secondaryAnimation ??
          const AlwaysStoppedAnimation(0),
      builder: (context, value, child) {
        final easedValue = Easing.standard.flipped.transform(value);
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            CupertinoTheme.of(
              context,
            ).barBackgroundColor.withValues(alpha: .5 * easedValue),
            BlendMode.srcOver,
          ),
          child: child!,
        );
      },
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            const CupertinoSliverNavigationBar(
              largeTitle: Text('Photos'),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisSpacing: 32,
                  crossAxisSpacing: 32,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Heroine(
                    tag: index,
                    motion: springNotifier.value,
                    flightShuttleBuilder: flightShuttleNotifier.value,
                    child: Cover(
                      index: index,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MyCustomRoute<void>(
                            settings: const RouteSettings(name: 'Details'),
                            fullscreenDialog: true,
                            title: 'Details',
                            builder: (context) => DetailsPage(index: index),
                          ),
                        );
                      },
                    ),
                  ),
                  childCount: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({
    required this.index,
    super.key,
    this.onPressed,
    this.isFlipped = false,
  });

  final int index;
  final bool isFlipped;
  final VoidCallback? onPressed;

  static final List<List<Color>> _gradients = [
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFf093fb), const Color(0xFFf5576c)],
    [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
    [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
    [const Color(0xFFfa709a), const Color(0xFFfee140)],
    [const Color(0xFFa8edea), const Color(0xFFfed6e3)],
    [const Color(0xFFff9a9e), const Color(0xFFfecfef)],
    [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFF89f7fe), const Color(0xFF66a6ff)],
    [const Color(0xFFee9ca7), const Color(0xFFffdde1)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
  ];

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
    );

    final gradientColors = _gradients[index % _gradients.length];

    return FilledButton(
      style: FilledButton.styleFrom(
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.all(32),
        shape: shape,
        backgroundColor: !isFlipped
            ? Colors.transparent
            : CupertinoColors.systemGrey4,
        foregroundColor: !isFlipped
            ? CupertinoColors.white
            : CupertinoColors.black,
        shadowColor: Colors.brown.withValues(alpha: .3),
        elevation: isFlipped ? 24 : 8,
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: isFlipped
                ? LinearGradient(
                    colors: [
                      CupertinoColors.systemGrey5.withValues(blue: .88),
                      CupertinoColors.systemGrey3.withValues(blue: .75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: child,
        ),
      ),
      child: isFlipped
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Card #$index',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle
                    .copyWith(
                      color: CupertinoColors.inactiveGray,
                    ),
              ),
            )
          : const SizedBox.shrink(),
      onPressed: onPressed,
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({
    required this.index,
    super.key,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    return ReactToHeroineDismiss(
      builder: (context, progress, offset, child) {
        final opacity = 1 - progress;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: opacity * 20,
              sigmaY: opacity * 20,
            ),
            child: CupertinoPageScaffold(
              backgroundColor: CupertinoTheme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: opacity),
              child: child!,
            ),
          ),
        );
      },
      child: CustomScrollView(
        slivers: [
          ReactToHeroineDismiss(
            builder: (context, progress, offset, child) {
              final opacity = 1 - progress;
              return SliverOpacity(
                opacity: opacity,
                sliver: child!,
              );
            },
            child: const CupertinoSliverNavigationBar(
              largeTitle: SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.sizeOf(context).height * .5,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: SingleMotionBuilder(
                  value: detailsPageAspectRatio.value,
                  motion: CupertinoMotion.bouncy(),
                  builder: (context, value, child) => AspectRatio(
                    aspectRatio: value,
                    child: DragDismissable(
                      child: child!,
                    ),
                  ),
                  child: Heroine(
                    tag: index,
                    motion: springNotifier.value,
                    flightShuttleBuilder: flightShuttleNotifier.value,
                    child: Cover(
                      index: index,
                      isFlipped: true,
                      // onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 48),
          ),
          ReactToHeroineDismiss(
            builder: (context, progress, offset, child) {
              final opacity = 1 - progress;
              return SliverOpacity(
                opacity: opacity,
                sliver: child!,
              );
            },
            child: SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'This is a demonstration of the Heroine package for '
                          'smooth hero transitions with custom motion. The '
                          'gradient cards transition smoothly between the grid '
                          'and detail views with backdrop blur effects.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
