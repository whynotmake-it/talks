import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// 1990s–2000s: Aqua-era “Stickies” demo.
/// Flow: start with a few open notes -> click "Stickies" (top bar)
/// -> a new note appears and auto-types "Buy milk"
/// -> drag that note onto the Dock trash area (bottom-right) -> note disappears
/// and a trash-full overlay appears. "Empty Trash" clears the overlay.
class AquaStickiesSlide extends FlutterDeckSlideWidget {
  const AquaStickiesSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/aqua-stickies',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;
    return FlutterDeckSlide.custom(
      builder: (_) => SizedBox.expand(
        child: ColoredBox(
          color: colorScheme.surfaceContainer,
          child: Center(
            child: Padding(
              padding: EdgeInsetsGeometry.all(32),
              child: AspectRatio(
                aspectRatio: 1280 / 1024,
                child: const _AquaDesktop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AquaDesktop extends StatefulWidget {
  const _AquaDesktop();
  @override
  State<_AquaDesktop> createState() => _AquaDesktopState();
}

class _AquaDesktopState extends State<_AquaDesktop>
    with TickerProviderStateMixin {
  final _desktopKey = GlobalKey();

  // Notes
  int _id = 0;
  final List<_Note> _notes = [];

  // Dragging
  _Note? _dragging;
  Offset? _fingerOffsetInNote; // NEW: finger offset relative to note top-left
  Rect? _trashRectGlobal;

  // Trash state
  bool _trashFull = false;
  late final AnimationController _trashBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final Animation<double> _trashScale = CurvedAnimation(
    parent: _trashBounce,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _notes.addAll([
      _Note(
        id: _nextId(),
        text: 'Welcome to Stickies\n(Leopard era)',
        pos: const Offset(120, 130),
      ),
      _Note(
        id: _nextId(),
        text: 'Tips:\n• Drag me around\n• Drop on Trash',
        pos: const Offset(210, 260),
      ),
      _Note(
        id: _nextId(),
        text: 'Click “Stickies” above\nfor a new note →',
        pos: const Offset(420, 160),
      ),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeTrashRect());
  }

  @override
  void dispose() {
    _trashBounce.dispose();
    super.dispose();
  }

  int _nextId() => _id++;

  void _spawnAutoNote() {
    final n = _Note(
      id: _nextId(),
      text: '',
      pos: const Offset(140, 90),
      autoType: 'Buy milk',
    );
    setState(() => _notes.add(n));
    n.startAutoType(setState);
  }

  void _computeTrashRect() {
    final rb = _desktopKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.hasSize) return;
    final size = rb.size;
    const double side = 120;
    final rectLocal = Rect.fromLTWH(
      size.width - side - 18,
      size.height - side - 18,
      side,
      side,
    );
    final topLeft = rb.localToGlobal(rectLocal.topLeft);
    _trashRectGlobal = topLeft & rectLocal.size;
  }

  // --- NEW DRAG LOGIC ---
  void _beginDrag(_Note n, DragStartDetails d) {
    setState(() {
      _dragging = n;
      _fingerOffsetInNote =
          d.localPosition; // where on the note the finger grabbed
      // bring to front
      _notes..removeWhere((x) => x.id == n.id)
      ..add(n);
    });
  }

  void _updateDrag(DragUpdateDetails d) {
    if (_dragging == null || _fingerOffsetInNote == null) return;
    final desktopBox =
        _desktopKey.currentContext?.findRenderObject() as RenderBox?;
    if (desktopBox == null || !desktopBox.hasSize) return;

    final fingerInDesktop = desktopBox.globalToLocal(d.globalPosition);
    final newTopLeft = fingerInDesktop - _fingerOffsetInNote!;
    setState(() => _dragging!.pos = newTopLeft);
  }

  void _endDrag(DragEndDetails d) {
    final drag = _dragging;
    _dragging = null;
    _fingerOffsetInNote = null;
    if (drag == null) return;

    final box = drag.key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _trashRectGlobal == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;

    if (_trashRectGlobal!.overlaps(rect)) {
      setState(() {
        _notes.removeWhere((n) => n.id == drag.id);
        _trashFull = true;
      });
      _trashBounce
        ..reset()
        ..forward();
    }
  }
  // --- end drag logic ---

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1280 / 1024,
      child: GestureDetector(
        child: Stack(
          key: _desktopKey,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/history/10-5-Leopard-Desktop.png',
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _TopBar(
                onTitleTap: _spawnAutoNote,
                onEmptyTrash: () => setState(() => _trashFull = false),
              ),
            ),
            Positioned.fill(
              child: Stack(
                children: [
                  for (final n in _notes)
                    _StickyNote(
                      key: n.key,
                      note: n,
                      onPanStart: (d) => _beginDrag(n, d),
                      onPanUpdate: _updateDrag,
                      onPanEnd: _endDrag,
                    ),
                ],
              ),
            ),
            Positioned(
              right: 86,
              bottom: 16,
              child: AnimatedOpacity(
                opacity: _trashFull ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.9,
                    end: 1,
                  ).animate(_trashScale),
                  child: Image.asset(
                    'assets/history/trash.png',
                    width: 96,
                    height: 96,
                  ),
                ),
              ),
            ),
            Positioned.fill(child: _AfterLayout(onLayout: _computeTrashRect)),
          ],
        ),
      ),
    );
  }
}

// ------- UI bits -------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onTitleTap, required this.onEmptyTrash});
  final VoidCallback onTitleTap;
  final VoidCallback onEmptyTrash;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xCCF6F6F6),
        border: const Border(bottom: BorderSide(color: Colors.black12)),
        boxShadow: const [
          BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black26),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTitleTap,
            child: Text(
              'Stickies',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Color(0xFF222222), Color(0xFF666666)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(const Rect.fromLTWH(0, 0, 100, 18)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('• click to make a new note', style: _hintStyle),
          const Spacer(),
          TextButton(
            onPressed: onEmptyTrash,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              foregroundColor: Colors.black87,
              backgroundColor: const Color(0x66FFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
  }
}

const _hintStyle = TextStyle(
  fontSize: 12,
  color: Colors.black54,
);

class _StickyNote extends StatelessWidget {
  const _StickyNote({
    required this.note,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final _Note note;
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: note.pos.dx,
      top: note.pos.dy,
      child: GestureDetector(
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: RepaintBoundary(
          child: Container(
            width: 260,
            constraints: const BoxConstraints(minHeight: 180),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF27A),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                  color: Color(0x55000000),
                ),
              ],
              border: Border.all(color: const Color(0xFFE3D85A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // glossy top strip (grab area)
                Container(
                  height: 26,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFBAB), Color(0xFFFFF27A)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      _chromeDot(const Color(0xFFFE5F57)),
                      const SizedBox(width: 6),
                      _chromeDot(const Color(0xFFFDBD2D)),
                      const SizedBox(width: 6),
                      _chromeDot(const Color(0xFF28C840)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: Text(
                    note.text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chromeDot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
    ),
  );
}

class _Note {
  _Note({
    required this.id,
    required this.text,
    required this.pos,
    this.autoType,
  });

  final int id;
  String text;
  Offset pos;
  final String? autoType;

  final key = GlobalKey();

  void startAutoType(void Function(void Function()) setState) {
    if (autoType == null || autoType!.isEmpty) return;
    var idx = 0;
    Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (idx >= autoType!.length) {
        t.cancel();
        return;
      }
      setState(() {
        text += autoType![idx];
        idx++;
      });
    });
  }
}

// Helper to update bounds after layout.
class _AfterLayout extends StatefulWidget {
  const _AfterLayout({required this.onLayout});
  final VoidCallback onLayout;
  @override
  State<_AfterLayout> createState() => _AfterLayoutState();
}

class _AfterLayoutState extends State<_AfterLayout> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLayout());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
