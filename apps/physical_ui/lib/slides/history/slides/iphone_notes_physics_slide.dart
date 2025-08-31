import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// Late 2000s: Touch + Physics (iPhone-style Notes)
/// Flow:
/// - Start on iPhone home screenshot (inside a custom 320×480 device frame)
/// - Tap Notes icon area -> opens Notes list with elastic scrolling
/// - Tap Stickies-style "+" -> opens editor; auto-types "Buy milk", then save
/// - Swipe to delete a note (Dismissible row)
class IphoneNotesPhysicsSlide extends FlutterDeckSlideWidget {
  const IphoneNotesPhysicsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/iphone-notes',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (_) => const _DeviceFramedDemo(),
    );
  }
}

class _DeviceFramedDemo extends StatelessWidget {
  const _DeviceFramedDemo();

  // Classic iPhone screen: 320×480 @1x (+ 20px status bar safe area).
  static final DeviceInfo _iphoneClassic = DeviceInfo.genericPhone(
    platform: TargetPlatform.iOS,
    name: 'iPhone (2007)',
    id: 'iphone2007',
    screenSize: const Size(320, 480),
    pixelRatio: 1,
    safeAreas: const EdgeInsets.only(top: 20), // status bar
    rotatedSafeAreas: const EdgeInsets.only(left: 20),
    // Use the GenericPhoneFramePainter you provided
    framePainter: const GenericPhoneFramePainter(
      // Slightly softer outer body and rounded corners
      outerBodyColor: Color(0xFF2B2B2B),
      innerBodyColor: Color(0xFF0E0E0E),
      outerBodyRadius: Radius.circular(44),
      innerBodyRadius: Radius.circular(40),

      // Bezels for the first iPhone (big forehead/chin)
      innerBodyInsets: EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 8),
      screenInsets: EdgeInsets.only(left: 16, top: 64, right: 16, bottom: 64),
      buttonColor: Color(0xFF111315),
      rightSideButtonsGapsAndSizes: [92, 78, 16, 78],
      topSideButtonsGapsAndSizes: [48, 76],

      // Tiny front camera dot (not actually on the 2007 model—kept subtle)
      cameraRadius: 4,
      cameraBorderWidth: 3,
      cameraBorderColor: Color(0xFF1E2426),
      cameraInnerColor: Color(0xFF0F1213),
      cameraReflectColor: Color(0xFF3E484C),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DeviceFrame(
        device: _iphoneClassic,
        screen: const _SpringboardToNotes(),
      ),
    );
  }
}

// =================== Screens ===================

enum _Stage { home, list, editor }

class _SpringboardToNotes extends StatefulWidget {
  const _SpringboardToNotes();

  @override
  State<_SpringboardToNotes> createState() => _SpringboardToNotesState();
}

class _SpringboardToNotesState extends State<_SpringboardToNotes> {
  _Stage _stage = _Stage.home;
  final List<String> _notes = [
    'Window measurements',
    'Groceries',
    'Birthday ideas',
    'Trip packing list',
    'Todo: call mom',
    'Book quotes',
    'Workshop outline',
    'FlutterCon ticket',
    'Get one of these flutter birds',
    'Have a good time',
  ];

  void _openList() => setState(() => _stage = _Stage.list);

  Future<void> _addNoteAuto() async {
    setState(() => _stage = _Stage.editor);
    // Let the editor run; it will pop back with a result.
    final text = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            const _NoteEditorAuto(textToType: 'Buy milk'),
      ),
    );
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _notes.insert(0, text.trim());
        _stage = _Stage.list;
      });
    } else {
      setState(() => _stage = _Stage.list);
    }
  }

  void _deleteAt(int index) => setState(() => _notes.removeAt(index));

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_stage) {
      case _Stage.home:
        body = _HomeScreen(onTapNotes: _openList);
      case _Stage.list:
        body = _NotesList(
          notes: _notes,
          onNew: _addNoteAuto,
          onDelete: _deleteAt,
        );
      case _Stage.editor:
        // (Editor is pushed as a route; keep list behind it.)
        body = _NotesList(
          notes: _notes,
          onNew: () {},
          onDelete: _deleteAt,
        );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: body,
    );
  }
}

// ---- Home (Springboard screenshot with tappable Notes icon area)
class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.onTapNotes});
  final VoidCallback onTapNotes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/history/IPhone_OS_1_screenshot.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Transparent tap target roughly where the Notes icon is
        Positioned(
          left: 168, // tweak to match your screenshot
          top: 224,
          width: 64,
          height: 64,
          child: GestureDetector(
            onTap: onTapNotes,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

// ---- Notes list (skeuomorphic-ish yellow paper + elastic scroll)
class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.onNew,
    required this.onDelete,
  });

  final List<String> notes;
  final VoidCallback onNew;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LeatherNavBar(title: 'Notes', onAdd: onNew),
        const Divider(height: 1, color: Color(0x55000000)),
        Expanded(
          child: Container(
            // Yellow paper background that fills the entire space
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF6D0),
                  Color(0xFFFFF3A0),
                ], // More authentic yellow tones
              ),
            ),
            child: CustomPaint(
              painter: _RuledPaperPainter(),
              child: ListView.builder(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: notes.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, i) => Dismissible(
                  key: ValueKey('note-$i-${notes[i]}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onDelete(i),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF6D0), Color(0xFFFFF3A0)],
                      ),
                    ),
                    child: const Icon(Icons.delete, color: Color(0xFFE74C3C)),
                  ),
                  child: _NoteRow(title: notes[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        14,
        0,
        14,
      ), // No right padding for full-width line
      decoration: const BoxDecoration(
        // Transparent background to let yellow paper show through
        border: Border(
          bottom: BorderSide(
            color: Color(0x40CCCCCC), // Subtle line that matches paper
            width: 0.8,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          right: 16,
        ), // Add right padding to text only
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            height: 1.3,
            fontFamily: 'Georgia',
            color: Color(0xFF2C2C2C),
          ),
        ),
      ),
    );
  }
}

// ---- Editor (auto-types Buy milk, then "Save")
class _NoteEditorAuto extends StatefulWidget {
  const _NoteEditorAuto({required this.textToType});
  final String textToType;
  @override
  State<_NoteEditorAuto> createState() => _NoteEditorAutoState();
}

class _NoteEditorAutoState extends State<_NoteEditorAuto> {
  String _text = '';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (_text.length >= widget.textToType.length) {
        t.cancel();
      } else {
        setState(() => _text += widget.textToType[_text.length]);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      child: Center(
        child: Container(
          width: 300,
          height: 380,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF6D0), Color(0xFFFFF3A0)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
          ),
          child: Column(
            children: [
              _LeatherNavBar(title: 'New Note', onAdd: () {}),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _RuledPaperPainter()),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          26,
                          20,
                          14,
                          16,
                        ), // Avoid margin line
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            _text,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.4, // Match the line spacing
                              fontFamily: 'Georgia',
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop<String>(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop<String>(_text.isEmpty ? widget.textToType : _text),
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Faux leather nav bar (evokes iOS 6 Notes)
class _LeatherNavBar extends StatelessWidget {
  const _LeatherNavBar({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B3B26), Color(0xFF3E281A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFF3A0),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 6,
            bottom: 6,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFF3A0),
                backgroundColor: const Color(0x22FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onAdd,
              child: const Text('+'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Lined yellow paper painter (matches original iPhone Notes design)
class _RuledPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle top shadow gradient
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, 20),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x20FFFFFF), Color(0x00FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, 20)),
      )
      // No horizontal lines in background - they'll be added in foreground
      // Left margin line (classic red margin)
      ..drawLine(
        const Offset(20, 0),
        Offset(20, size.height + 100),
        Paint()
          ..color =
              const Color(0x60FF6B6B) // Softer red margin line
          ..strokeWidth = 0.8,
      );

    // Subtle paper texture (very light noise)
    final texturePaint = Paint()
      ..color = const Color(0x08000000)
      ..style = PaintingStyle.fill;

    // Add tiny dots for paper texture
    for (double x = 0; x < size.width; x += 8) {
      for (double y = 0; y < size.height + 100; y += 8) {
        if ((x + y) % 16 == 0) {
          canvas.drawCircle(Offset(x, y), 0.3, texturePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
