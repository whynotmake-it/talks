import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// Command-line era demo: create a note and delete it.
/// Each deck step reveals the next interaction with a type-on animation.
class CommandLineSlide extends FlutterDeckSlideWidget {
  const CommandLineSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/cli',
          steps: 7,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, step) {
          return _CliTerminal(step: step);
        },
      ),
    );
  }
}

/// The terminal surface that switches content by step.
class _CliTerminal extends StatelessWidget {
  const _CliTerminal({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: 'monospace',
      height: 1.3,
      fontSize: 20,
      color: const Color(0xFFBDE07B), // soft green phosphor vibe
    );

    return Center(
      child: _Apple2Frame(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: mono!,
            child: _StepContent(step: step),
          ),
        ),
      ),
    );
  }
}

class _Apple2Frame extends StatelessWidget {
  const _Apple2Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/history/apple2.png',
          fit: BoxFit.contain,
        ),
        Positioned(
          top: 140,
          left: 256,
          right: 256,
          bottom: 500,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Renders all lines for the current step. Only the newest command types in.
class _StepContent extends StatelessWidget {
  const _StepContent({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];

    // Step 1: show static prompt, Step 2: replace with typing command.
    if (step == 1) {
      lines.add(_promptStatic());
    } else if (step >= 2) {
      lines
        ..add(_promptWithTyping('echo "Buy milk" > note.txt'))
        ..add(const SizedBox(height: 6));
    }

    // Step 3: read the note (show content as output after typing).
    if (step >= 3) {
      lines
        ..add(
          _PromptAndOutput(
            command: 'cat note.txt',
            output: 'Buy milk',
          ),
        )
        ..add(const SizedBox(height: 6));
    }

    // Step 4: delete the note.
    if (step >= 4) {
      lines
        ..add(_promptWithTyping('rm note.txt'))
        ..add(const SizedBox(height: 6));
    }

    // Step 5: try to read again → error.
    if (step >= 5) {
      lines
        ..add(
          _PromptAndOutput(
            command: 'cat note.txt',
            output: 'cat: note.txt: No such file or directory',
            isError: true,
          ),
        )
        ..add(const SizedBox(height: 6));
    }

    // Step 6: idle prompt again.
    if (step >= 6) {
      lines.add(_promptStatic());
    }

    // Step 7: takeaway comment.
    if (step >= 7) {
      lines.add(const SizedBox(height: 10));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  Widget _promptStatic() => Row(
    children: const [
      Text(r'guest@host:~$ '),
      _BlinkingCursor(),
    ],
  );

  Widget _promptWithTyping(String command) => Row(
    children: [
      const Text(r'guest@host:~$ '),
      _OneShotTypewriter(
        text: command,
        speed: const Duration(milliseconds: 42),
      ),
    ],
  );
}

/// A prompt + command that types in, then reveals output underneath.
class _PromptAndOutput extends StatefulWidget {
  const _PromptAndOutput({
    required this.command,
    required this.output,
    this.isError = false,
  });

  final String command;
  final String output;
  final bool isError;

  @override
  State<_PromptAndOutput> createState() => _PromptAndOutputState();
}

class _PromptAndOutputState extends State<_PromptAndOutput> {
  bool _showOutput = false;

  @override
  Widget build(BuildContext context) {
    final outputStyle = DefaultTextStyle.of(context).style.copyWith(
      color: widget.isError ? const Color(0xFFFF8888) : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(r'guest@host:~$ '),
            _OneShotTypewriter(
              text: widget.command,
              speed: const Duration(milliseconds: 42),
              onDone: () => setState(() => _showOutput = true),
            ),
          ],
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          opacity: _showOutput ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DefaultTextStyle.merge(
              style: outputStyle,
              child: Text(widget.output),
            ),
          ),
        ),
      ],
    );
  }
}

/// Minimal, dependable type-on that never deletes.
class _OneShotTypewriter extends StatefulWidget {
  const _OneShotTypewriter({
    required this.text,
    required this.speed,
    this.onDone,
  });

  final String text;
  final Duration speed; // per grapheme
  final VoidCallback? onDone;

  @override
  State<_OneShotTypewriter> createState() => _OneShotTypewriterState();
}

class _OneShotTypewriterState extends State<_OneShotTypewriter> {
  late final List<String> _g;
  int _visible = 0;
  Timer? _t;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _g = widget.text.characters.toList();
    _tick();
  }

  void _tick() {
    _t?.cancel();
    if (_visible < _g.length) {
      _t = Timer(widget.speed, () {
        if (!mounted) return;
        setState(() => _visible++);
        _tick();
      });
    } else if (!_done) {
      _done = true;
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _visible <= 0 ? '' : _g.take(_visible).join();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(shown, softWrap: false),
        if (!_done) const _BlinkingCursor(),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.white;
    final fs = DefaultTextStyle.of(context).style.fontSize ?? 20;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _c,
          curve: Curves.easeInOut,
        ),
      ),
      child: Container(
        width: fs * 0.55,
        height: fs * 1.15,
        margin: const EdgeInsets.only(left: 2),
        color: color,
      ),
    );
  }
}
