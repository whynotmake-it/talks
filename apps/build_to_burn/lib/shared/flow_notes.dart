import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A rehearsal aid, not part of the talk: each slide's guiding question,
/// what the audience should take away, and the line that leads on.
///
/// Press F to show or hide it on every slide.
class FlowNote {
  const FlowNote({
    required this.question,
    required this.takeaway,
    required this.transition,
  });

  /// The question this slide answers, as the audience would ask it.
  final String question;

  /// What the audience should remember from this slide.
  final String takeaway;

  /// The last line, which raises the next slide's question.
  final String transition;
}

/// The flow notes, by slide route.
const flowNotes = {
  '/title': FlowNote(
    question: 'What is this talk about?',
    takeaway: "We'll follow one frame from your code to the GPU.",
    transition: "Let's start with code you all know.",
  ),
  '/cold-open': FlowNote(
    question: 'What are we looking at?',
    takeaway: 'An ordinary screen: a list, a search bar, a blur.',
    transition: 'This screen kept the GPU busy. Guess why.',
  ),
  '/hook': FlowNote(
    question: 'What keeps the GPU busy?',
    takeaway: 'They commit to a guess, so they care about the answer.',
    transition: 'To answer it, we follow one frame through Flutter.',
  ),
  '/stage-2': FlowNote(
    question: 'What does Flutter make from my widgets?',
    takeaway:
        'Widgets become render objects, and render objects do the real '
        'work. The docs explain this well.',
    transition: 'One of their jobs is painting. What does that look like?',
  ),
  '/paint-source': FlowNote(
    question: 'What does paint actually look like?',
    takeaway:
        'Two signatures you may have seen. Paint is just a method with a '
        'canvas.',
    transition: 'So what happens when our demo paints?',
  ),
  '/stage-3': FlowNote(
    question: 'Does paint draw to the screen?',
    takeaway:
        'No. Dart on the CPU writes down instructions. They are recorded '
        'into pictures, sorted into layers.',
    transition: 'So what does paint leave behind?',
  ),
  '/stage-4': FlowNote(
    question: 'What does paint leave behind, and how does it reach the engine?',
    takeaway:
        'A layer tree with four pictures. The pictures went to C++ while '
        'painting; the SceneBuilder copies the layers at the end of the '
        'frame. Together: one Scene.',
    transition: 'The raster thread takes the Scene. What does it do with it?',
  ),
  '/stage-5': FlowNote(
    question: 'What does the raster thread do with the Scene?',
    takeaway:
        'The tree is built for change, the GPU takes lists. Every layer '
        'becomes a rule, every picture a line. The blur is one line.',
    transition: 'Remember that line: the GPU has to stop right there.',
  ),
  '/gpu': FlowNote(
    question: 'Why is that one blur line expensive?',
    takeaway:
        'The GPU paints tiles in parallel, on chip. The blur needs finished '
        'neighbours, so the frame goes out to memory and back.',
    transition: "Impeller plans this ahead. Let's see it in our list.",
  ),
  '/stage-6': FlowNote(
    question: 'Where does the work get cut?',
    takeaway:
        'Impeller cuts the list at the blur: pass 1, the blur, pass 2. Six '
        'passes in our capture.',
    transition: 'Now we know what one frame costs. Mystery solved? Live.',
  ),
  '/live': FlowNote(
    question: 'Is the blur the answer?',
    takeaway:
        'Not alone: unfocused, the needle sits in green. Focused, it goes '
        'to yellow and stays.',
    transition: 'Same screen, same blur. What changed?',
  ),
  '/every-frame': FlowNote(
    question: 'What does the spike mean?',
    takeaway: 'The round trip now runs every frame, 120 times a second.',
    transition: 'But why every frame? Who keeps asking?',
  ),
  '/quiz-answer': FlowNote(
    question: 'So what keeps the GPU busy?',
    takeaway:
        'Both: the blur makes each frame expensive, the cursor makes many '
        'frames.',
    transition: 'Is the cursor why we run at full frame rate?',
  ),
  '/paint-vs-composite': FlowNote(
    question: 'Why 120 frames for a caret that changes 8 times a second?',
    takeaway:
        'Repaints are 8 a second, but the ticker asks for a frame every '
        'vsync, and each frame runs the Scene, raster and GPU.',
    transition: 'Why did no tool warn us?',
  ),
  '/fast-not-cheap': FlowNote(
    question: 'Why did DevTools look fine?',
    takeaway:
        'DevTools answers "is it fast?". GPU and energy tools answer '
        '"is it cheap?". You need both.',
    transition: 'So how do you measure the price? The GPU tools.',
  ),
};

/// Whether the flow notes show. Toggled with F.
final flowNotesVisible = ValueNotifier(false);

/// Toggles [flowNotesVisible] when F is pressed, anywhere in the deck.
class FlowNotesShortcut extends StatefulWidget {
  const FlowNotesShortcut({required this.child, super.key});

  final Widget child;

  @override
  State<FlowNotesShortcut> createState() => _FlowNotesShortcutState();
}

class _FlowNotesShortcutState extends State<FlowNotesShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyF) {
      return false;
    }
    flowNotesVisible.value = !flowNotesVisible.value;
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The flow note for [route], over the slide, while [flowNotesVisible].
class FlowNoteOverlay extends StatelessWidget {
  const FlowNoteOverlay({required this.route, super.key});

  final String route;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: flowNotesVisible,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();
        final note = flowNotes[route];
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 32),
              decoration: BoxDecoration(
                color: const Color(0xEE16181D),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: note == null
                  ? _row('FLOW', 'No flow note for $route yet.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('QUESTION', note.question),
                        const SizedBox(height: 16),
                        _row('TAKEAWAY', note.takeaway),
                        const SizedBox(height: 16),
                        _row('NEXT', note.transition),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 220,
        child: Text(
          label,
          style: mono(24, weight: 600, color: const Color(0xFF8AB4F8)),
        ),
      ),
      Expanded(
        child: Text(
          text,
          style: archivo(32, height: 1.3, color: const Color(0xFFF1F3F4)),
        ),
      ),
    ],
  );
}
