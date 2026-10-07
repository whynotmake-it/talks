import 'package:build_to_burn/shared/inline_mark.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/tips/blur_demos.dart';
import 'package:build_to_burn/visualizations/tips/frame_demos.dart';
import 'package:build_to_burn/visualizations/tips/opacity_demos.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// One tip: a short fragment, an optional API name, whether it comes with a
/// trade-off, and the demo that shows it.
class _Tip {
  const _Tip(this.text, {required this.demo, this.code, this.tradeoff = false});

  final String text;

  /// The API that does it, shown under [text] in mono.
  final String? code;

  /// Whether the tip costs something, marked with a red dot.
  final bool tradeoff;

  final Widget demo;
}

/// The heading every closing slide shares, with an optional trailing widget
/// on the right.
class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: archivo(92, height: 1.05, spacing: -3, color: p.text),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rows separated by hairlines, the list style of the closing slides.
class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;
  static const _rowHeight = 184.0;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final line = BorderSide(color: p.borderStrong, width: 2);
    return Column(
      children: [
        for (final (index, child) in children.indexed)
          Container(
            height: _rowHeight,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                top: line,
                bottom: index == children.length - 1 ? line : BorderSide.none,
              ),
            ),
            child: child,
          ),
      ],
    );
  }
}

/// The layout for the tip slides: a heading, the tips on the left and the
/// current tip's demo on the right. Each step moves to the next tip.
class _TipList extends StatelessWidget {
  const _TipList({required this.title, required this.tips});

  final String title;
  final List<_Tip> tips;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SlideFrame(
      child: FlutterDeckSlideStepsBuilder(
        builder: (context, step) {
          final current = (step - 1).clamp(0, tips.length - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(
                title,
                trailing: tips.any((tip) => tip.tradeoff)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const InlineMark(
                            fontSize: 32,
                            size: 20,
                            child: _Dot(size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'trade-off',
                            style: archivo(32, color: p.textSecondary),
                          ),
                        ],
                      )
                    : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The demo is a square on the right; the tips share the
                    // rest. The current tip sits in a box that merges with
                    // the demo's.
                    final stage = constraints.maxHeight;
                    final listWidth = constraints.maxWidth - stage;
                    final rowHeight = stage / tips.length;
                    final border = BorderSide(color: p.border, width: 2);
                    return Stack(
                      children: [
                        Positioned(
                          right: 0,
                          top: 0,
                          width: stage,
                          height: stage,
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: p.surface,
                              border: Border.fromBorderSide(border),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              // Demos are laid out on a fixed square and
                              // scaled to the stage.
                              child: FittedBox(
                                key: ValueKey(current),
                                child: SizedBox.square(
                                  dimension: 720,
                                  child: tips[current].demo,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Reaches over the demo's left border to open the
                        // two boxes into one.
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: easeInOut,
                          left: 0,
                          top: current * rowHeight,
                          width: listWidth + border.width,
                          height: rowHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.surface,
                              border: Border(
                                top: border,
                                left: border,
                                bottom: border,
                              ),
                            ),
                          ),
                        ),
                        for (final (index, tip) in tips.indexed)
                          Positioned(
                            left: 0,
                            top: index * rowHeight,
                            width: listWidth,
                            height: rowHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _TipRow(tip: tip),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tip.text,
                style: archivo(
                  54,
                  weight: 500,
                  height: 1.1,
                  spacing: -1,
                  color: p.text,
                ),
              ),
              if (tip.code != null) ...[
                const SizedBox(height: 10),
                Text(tip.code!, style: mono(36, color: p.accent)),
              ],
            ],
          ),
        ),
        if (tip.tradeoff) ...[
          const SizedBox(width: 24),
          const InlineMark(fontSize: 54, size: 28, child: _Dot(size: 28)),
        ],
      ],
    );
  }
}

/// The red dot that marks a trade-off.
class _Dot extends StatelessWidget {
  const _Dot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: heat, shape: BoxShape.circle),
    );
  }
}

/// The section opener for the closing recommendations.
class WhatToDoSlide extends FlutterDeckSlideWidget {
  const WhatToDoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/what-to-do',
          title: 'What can you do about it',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        final style = p.hero.copyWith(fontSize: 136);
        return SlideFrame(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  const TextSpan(text: 'What can you'),
                  TextSpan(
                    text: '(r Agent)',
                    style: style.copyWith(color: p.accent),
                  ),
                  const TextSpan(text: '\ndo about it?'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pay for fewer frames: stop or slow what keeps requesting them.
class FrameDemandFixesSlide extends FlutterDeckSlideWidget {
  const FrameDemandFixesSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/frame-demand-fixes',
          title: 'Fewer frames',
          steps: 3,
          speakerNotes:
              '$timSlideNotesHeader\n'
              'fixed_ticker runs a ticker at a fixed rate instead of every '
              'vsync: swap the ticker provider mixin, or wrap a subtree in '
              'TickerRateScope. Subtle, long animations look the same at '
              '10–30 fps; fast motion gets choppy. TickerMode(enabled: '
              'false) for what you hide yourself; routes under an opaque '
              'route are already muted. cursorOpacityAnimates: false turns '
              'the smooth caret fade into a timer blink — a visible change.',
        ),
      );

  static const _tips = [
    _Tip(
      'Timer-based animations',
      code: 'package:fixed_ticker',
      tradeoff: true,
      demo: TimerSpinnersDemo(),
    ),
    _Tip(
      'Stop hidden animations',
      code: 'TickerMode',
      demo: HiddenRouteDemo(),
    ),
    _Tip(
      'Blink the caret',
      code: 'cursorOpacityAnimates: false',
      tradeoff: true,
      demo: CaretDemo(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const _TipList(title: 'Fewer frames', tips: _tips),
    );
  }
}

/// Make each blur cheaper.
class TakeawaysSlide extends FlutterDeckSlideWidget {
  const TakeawaysSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/takeaways',
          title: 'Blur',
          steps: 3,
          speakerNotes:
              '$timSlideNotesHeader\n'
              'Impeller downsamples a blur once its scaled sigma passes 4, '
              'and the larger the sigma the further it downsamples, so the '
              'blur passes work on a smaller texture — but the look changes. '
              'BackdropFilter.grouped under a BackdropGroup runs one blur '
              'for the group — only when every member uses the same '
              'ImageFilter.blur. Animate sigma to '
              'exactly 0: the engine drops a blur with both sigmas below '
              '1/4096.',
        ),
      );

  static const _tips = [
    _Tip(
      'Bigger sigma, cheaper blur',
      tradeoff: true,
      demo: SigmaDownsampleDemo(),
    ),
    _Tip(
      'Group backdrop filters',
      code: 'BackdropGroup, same ImageFilter.blur',
      demo: GroupedBlurDemo(),
    ),
    _Tip('Animate sigma to exactly 0', demo: SigmaZeroDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const _TipList(title: 'Blur', tips: _tips),
    );
  }
}

/// Ways to avoid paying for an offscreen layer.
class LayerCostsSlide extends FlutterDeckSlideWidget {
  const LayerCostsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/layer-costs',
          title: 'Opacity',
          steps: 4,
          speakerNotes:
              '$timSlideNotesHeader\n'
              'Opacity over a single non-overlapping child is already free: '
              'the opacity peephole puts the alpha into the paint. Over '
              'overlapping content it needs a layer; alpha in each paint '
              'avoids it but lets overlaps show through. '
              'A translucent srcOver overlay in the background color fakes '
              'Opacity, and a gradient in the background color fakes a '
              'ShaderMask edge fade, with no layer — but only over a solid, '
              'known background. Not BlendMode.overlay. ShaderMask is always '
              'a layer; give saveLayer tight bounds.',
        ),
      );

  static const _tips = [
    _Tip(
      'Alpha in the paint',
      code: 'Image(opacity:), Color.withValues',
      tradeoff: true,
      demo: AlphaInPaintDemo(),
    ),
    _Tip(
      'Color overlay, not Opacity',
      tradeoff: true,
      demo: ColorOverlayDemo(),
    ),
    _Tip(
      'Gradient, not ShaderMask',
      tradeoff: true,
      demo: GradientFadeDemo(),
    ),
    _Tip('Keep layers tight', code: 'saveLayer', demo: TightLayerDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const _TipList(title: 'Opacity', tips: _tips),
    );
  }
}

/// Our agent skills.
class SkillsSlide extends FlutterDeckSlideWidget {
  const SkillsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/skills',
          title: 'Skills',
          speakerNotes:
              '$timSlideNotesHeader\n'
              'Shipped in packages/impeeler/skills. gpu-cost is the entry '
              'point: install the binding, estimate, reduce, lock in a '
              'budget, and hand off to the other two. frame-demand: '
              'find tickers and timers, slow or stop them. gpu-profiling: '
              'confirm on a device with Xcode, Instruments, AGI, RenderDoc.',
        ),
      );

  static const _skills = [
    ('impeeler-gpu-cost', 'Start here: what makes it expensive?'),
    ('impeeler-frame-demand', 'Why does it keep drawing?'),
    ('impeeler-gpu-profiling', 'What does a real device say?'),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading('Skills for your agent'),
              _Rows(
                children: [
                  for (final (name, question) in _skills)
                    Row(
                      children: [
                        SizedBox(
                          width: 720,
                          child: Text(
                            name,
                            style: mono(44, weight: 600, color: p.accent),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            question,
                            style: archivo(52, height: 1.15, color: p.text),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The last slide: thank you, and one page with every link, as a large
/// address and a QR code.
class ReadingMaterialsSlide extends FlutterDeckSlideWidget {
  const ReadingMaterialsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/reading-materials',
          title: 'Thank you',
          speakerNotes:
              '$timSlideNotesHeader\n'
              'https://madethese.works/gpu/ — impeeler and its skills, '
              'fixed_ticker, the architectural overview, the Impeller docs.',
        ),
      );

  /// The attendee page with every link from the talk.
  static const _linksUrl = 'https://madethese.works/gpu/';

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading('Thank you'),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'madethese.works/gpu',
                          style: archivo(
                            150,
                            weight: 600,
                            spacing: -5,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 80),
                    QrImageView(
                      data: _linksUrl,
                      size: 380,
                      padding: EdgeInsets.zero,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: p.text,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
