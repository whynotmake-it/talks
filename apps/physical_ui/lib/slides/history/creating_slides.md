Flutter Deck
API Docs
 
Welcome
Get Started
Live demo
Showcase
Guides
Creating slides
Theming
Widgets
Multi-Step slides
Hiding slides
Initial slide
Localization
Transitions
Presentation state
Code generation
Slide Templates
Title slide
Big Fact slide
Image slide
Quote slide
Split slide
Template slide
Blank slide
Custom slide
Playback
Controls
Navigation drawer
Marker tool
Auto-Play
Change locale
Presenter view
Contributors (16)
+12
Creating slides
There are multiple ways to create slides for your presentation. Here are a few options:

Using any Widget as a slide
When defining slides for your presentation, you can use any widget as a slide. This is the most straightforward way to create slides. However, you won't be able to specify the slide's configuration, and the default slide configuration will be used.

FlutterDeckApp(
  configuration: const FlutterDeckConfiguration(...),
  slides: [
    Scaffold(
      backgroundColor: Colors.blue,
      body: Builder(
        builder: (context) => Center(
          child: Text(
            'You can use any widget as a slide!',
            style: FlutterDeckTheme.of(context).textTheme.title,
          ),
        ),
      ),
    ),
  ],
);
Using the withSlideConfiguration extension
The withSlideConfiguration extension allows you to specify the configuration for a slide. You can still use any widget as a slide, but you can also specify the slide's configuration.

FlutterDeckApp(
  configuration: const FlutterDeckConfiguration(...),
  slides: [
    Scaffold(
      backgroundColor: Colors.blue,
      body: Builder(
        builder: (context) => Center(
          child: Text(
            'You can use any widget as a slide!',
            style: FlutterDeckTheme.of(context).textTheme.title,
          ),
        ),
      ),
    ).withSlideConfiguration(
      const FlutterDeckSlideConfiguration(
        route: '/custom',
        title: 'Custom Slide',
        speakerNotes: 'You can use any widget as a slide!',
        footer: FlutterDeckFooterConfiguration(showFooter: false),
      ),
    ),
  ],
);
Using the FlutterDeckSlide template
The FlutterDeckSlide templates allow you to create slides with a specific layout. To see the available templates, check the Slide Templates section in the documentation.

FlutterDeckApp(
  configuration: const FlutterDeckConfiguration(...),
  slides: [
    FlutterDeckSlide.custom(
      configuration: const FlutterDeckSlideConfiguration(
        route: '/custom',
        title: 'Custom Slide',
        speakerNotes: 'You can use any widget as a slide!',
        footer: FlutterDeckFooterConfiguration(showFooter: false),
      ),
      builder: (context) => Scaffold(
        backgroundColor: Colors.blue,
        body: Center(
          child: Text(
            'You can use any widget as a slide!',
            style: FlutterDeckTheme.of(context).textTheme.title,
          ),
        ),
      ),
    ),
  ],
);
Subclassing the FlutterDeckSlideWidget
You can also subclass the FlutterDeckSlideWidget to create custom slides. This way, you can separate the slide's configuration from the slide's content.

First, create a new slide widget:

class CustomSlide extends FlutterDeckSlideWidget {
  const CustomSlide()
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/custom',
            title: 'Custom Slide',
            speakerNotes: 'You can use any widget as a slide!',
            footer: FlutterDeckFooterConfiguration(showFooter: false),
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => Scaffold(
        backgroundColor: Colors.blue,
        body: Center(
          child: Text(
            'You can use any widget as a slide!',
            style: FlutterDeckTheme.of(context).textTheme.title,
          ),
        ),
      ),
    );
  }
}
Then, add the slide to your presentation:

FlutterDeckApp(
  configuration: const FlutterDeckConfiguration(...),
  slides: const [
    CustomSlide(),
  ],
);
Using any Widget as a slide
Using the withSlideConfiguration extension
Using the FlutterDeckSlide template
Subclassing the FlutterDeckSlideWidget
BUILT WITH STATIC SHOCK