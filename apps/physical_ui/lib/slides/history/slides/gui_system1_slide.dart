import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// 1980s GUI (Apple System 1–ish) demo. Desktop metaphor, direct manipulation.
/// Flow: Apple → Note Pad → type "Buy milk" → Save to Desktop
/// → drag outline to Trash.
class GuiSystem1Slide extends FlutterDeckSlideWidget {
  const GuiSystem1Slide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/gui',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (_) => const _System1Desktop(),
    );
  }
}

// ===== Desktop state =====
class _System1Desktop extends StatefulWidget {
  const _System1Desktop();
  @override
  State<_System1Desktop> createState() => _System1DesktopState();
}

class _System1DesktopState extends State<_System1Desktop>
    with SingleTickerProviderStateMixin {
  final _trashKey = GlobalKey();
  final _desktopKey = GlobalKey();

  Rect _trashRect = Rect.zero;
  int _idCounter = 0;

  // User-created notes (right column icons are static/anchored)
  final List<_DesktopItem> _notes = [];

  // Windows / menus
  _DesktopItem? _openNote;
  bool _showNotepad = false;
  String? _openMenu; // 'Apple' | 'File' | 'Edit' | 'View' | 'Special'

  // Drag outline state
  _DesktopItem? _draggingItem;
  Rect? _dragRectGlobal; // follows pointer in global coords
  late final AnimationController _antsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _antsController.dispose();
    super.dispose();
  }

  int _nextId() => _idCounter++;

  void _onTapDesktop() {
    setState(() {
      _openMenu = null;
      for (final i in _notes) {
        i.selected = false;
      }
    });
  }

  void _newNote({String content = 'Buy milk'}) {
    final idx = _notes.length + 1;
    final note = _DesktopItem(
      id: _nextId(),
      type: _IconType.note,
      title: 'Note $idx',
      // start near top-left, adapts to any size
      position: const Offset(64, 80),
      content: content,
    );
    setState(() => _notes.add(note));
  }

  void _emptyTrash() {
    // Trash emptied silently
  }

  void _updateTrashRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _trashKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        setState(() {
          _trashRect = offset & box.size;
        });
      }
    });
  }

  void _openNoteWindow(_DesktopItem item) {
    setState(() => _openNote = item);
  }

  void _closeNoteWindow() => setState(() => _openNote = null);

  // ---- Drag outline handling ----
  void _beginDrag(_DesktopItem item, Rect startRectGlobal) {
    setState(() {
      _draggingItem = item;
      _dragRectGlobal = startRectGlobal;
    });
    if (!_antsController.isAnimating) _antsController.repeat();
  }

  void _updateDrag(Offset globalDelta) {
    if (_dragRectGlobal == null) return;
    final desktopBox =
        _desktopKey.currentContext?.findRenderObject() as RenderBox?;
    if (desktopBox == null || !desktopBox.hasSize) return;

    // Move and clamp within desktop (with small margins)
    final deskOrigin = desktopBox.localToGlobal(Offset.zero);
    final deskRect = deskOrigin & desktopBox.size;

    final next = _dragRectGlobal!.shift(globalDelta);

    const pad = 4.0;
    final minLeft = deskRect.left + pad;
    final minTop = deskRect.top + 32; // keep below menu bar
    final maxLeft = deskRect.right - next.width - pad;
    final maxTop =
        deskRect.bottom -
        next.height -
        72; // avoid overlapping trash area too much

    final clamped = Offset(
      next.left.clamp(minLeft, maxLeft),
      next.top.clamp(minTop, maxTop),
    );
    setState(() {
      _dragRectGlobal = Rect.fromLTWH(
        clamped.dx,
        clamped.dy,
        next.width,
        next.height,
      );
    });
  }

  void _endDrag() {
    final dragging = _draggingItem;
    final rect = _dragRectGlobal;
    if (dragging == null || rect == null) return;

    // If hovering trash → delete
    if (_trashRect.overlaps(rect)) {
      setState(() {
        _notes.removeWhere((e) => e.id == dragging.id);
        _openNote = _openNote?.id == dragging.id ? null : _openNote;
      });
    } else {
      // Commit new position to desktop coords
      final desktopBox =
          _desktopKey.currentContext?.findRenderObject() as RenderBox?;
      if (desktopBox != null && desktopBox.hasSize) {
        final local = desktopBox.globalToLocal(rect.topLeft);
        setState(() => dragging.position = local);
      }
    }

    setState(() {
      _draggingItem = null;
      _dragRectGlobal = null;
    });
    _antsController.stop();
  }

  @override
  Widget build(BuildContext context) {
    final antsPhase = _antsController.value; // 0→1 for marching ants
    final trashHighlight =
        _dragRectGlobal != null && _trashRect.overlaps(_dragRectGlobal!);

    return GestureDetector(
      onTap: _onTapDesktop,
      child: Stack(
        key: _desktopKey,
        fit: StackFit.expand,
        children: [
          const _DitheredBackground(),

          // Menu bar
          Align(
            alignment: Alignment.topCenter,
            child: _System1MenuBar(
              onOpenMenu: (m) =>
                  setState(() => _openMenu = _openMenu == m ? null : m),
            ),
          ),

          // Anchored right column icons (static)
          Positioned(
            right: 18,
            top: 36,
            child: const _StaticIcon(
              type: _IconType.floppy,
              label: 'System Disk',
            ),
          ),
          Positioned(
            right: 18,
            top: 156,
            child: const _StaticIcon(type: _IconType.doc, label: 'Welcome!'),
          ),
          Positioned(
            right: 18,
            top: 276,
            child: const _StaticIcon(
              type: _IconType.floppy,
              label: 'Infinite HD',
            ),
          ),

          // User notes (draggable via outline)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  children: [
                    for (final item in _notes)
                      _IconWidget(
                        key: item.key,
                        item: item,
                        desktopSize: size,
                        onDoubleTap: () => _openNoteWindow(item),
                        onBeginDrag: (rect) => _beginDrag(item, rect),
                        onDragUpdate: _updateDrag,
                        onEndDrag: _endDrag,
                        dragActive: _draggingItem?.id == item.id,
                      ),

                    // Trash (fixed bottom-right)
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: _TrashIcon(
                        key: _trashKey,
                        highlight: trashHighlight,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Notepad window (Desk Accessory)
          if (_showNotepad)
            Positioned.fill(
              child: Center(
                child: _NotePadWindow(
                  onClose: () => setState(() => _showNotepad = false),
                  onSaveToDesktop: (text) {
                    _newNote(content: text.isNotEmpty ? text : 'Buy milk');
                  },
                ),
              ),
            ),

          // Note window (double-clicked note)
          if (_openNote != null)
            Positioned.fill(
              child: Center(
                child: _NoteWindow(
                  title: _openNote!.title,
                  content: _openNote!.content ?? '',
                  onClose: _closeNoteWindow,
                ),
              ),
            ),

          // Drop-down menus rendered ABOVE everything
          if (_openMenu != null) ...[
            // click-away layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _openMenu = null),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: _menuLeftOffset(_openMenu!),
              top: 28,
              child: _MenuPanel(
                children: _menuEntries(_openMenu!),
              ),
            ),
          ],

          // Drag outline (marching ants) drawn last so it's on top
          if (_dragRectGlobal != null)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Convert global rect to local coordinates
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox == null) {
                      return CustomPaint(
                        painter: _DragOutlinePainter(
                          rectLocal: _dragRectGlobal!,
                          phase: antsPhase,
                        ),
                      );
                    }

                    final globalTopLeft = _dragRectGlobal!.topLeft;
                    final globalBottomRight = _dragRectGlobal!.bottomRight;
                    final localTopLeft = renderBox.globalToLocal(globalTopLeft);
                    final localBottomRight = renderBox.globalToLocal(
                      globalBottomRight,
                    );
                    final localRect = Rect.fromPoints(
                      localTopLeft,
                      localBottomRight,
                    );

                    return CustomPaint(
                      painter: _DragOutlinePainter(
                        rectLocal: localRect,
                        phase: antsPhase,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Keep our trash rect updated
          Positioned.fill(child: _AfterLayout(onLayout: _updateTrashRect)),
        ],
      ),
    );
  }

  double _menuLeftOffset(String menu) {
    switch (menu) {
      case 'Apple':
        return 8;
      case 'File':
        return 60;
      case 'Edit':
        return 120;
      case 'View':
        return 180;
      case 'Special':
        return 250;
      default:
        return 60;
    }
  }

  List<Widget> _menuEntries(String menu) {
    if (menu == 'Apple') {
      return [
        const _MenuItem(label: 'About the Finder…', enabled: false),
        const _MenuSeparator(),
        const _MenuItem(label: 'Scrapbook', enabled: false),
        const _MenuItem(label: 'Alarm Clock', enabled: false),
        _MenuItem(
          label: 'Note Pad',
          onTap: () {
            setState(() {
              _showNotepad = true;
              _openMenu = null;
            });
          },
        ),
        const _MenuItem(label: 'Key Caps', enabled: false),
        const _MenuItem(label: 'Control Panel', enabled: false),
        const _MenuItem(label: 'Puzzle', enabled: false),
        const _MenuItem(label: 'Monkey', enabled: false),
      ];
    }
    if (menu == 'File') {
      return [
        _MenuItem(
          label: 'New Note',
          onTap: () {
            _newNote();
            setState(() => _openMenu = null);
          },
        ),
        const _MenuSeparator(),
        _MenuItem(
          label: 'Empty Trash',
          onTap: () {
            _emptyTrash();
            setState(() => _openMenu = null);
          },
        ),
      ];
    }
    if (menu == 'Edit') {
      return const [
        _MenuItem(label: 'Undo', enabled: false),
        _MenuItem(label: 'Cut', enabled: false),
        _MenuItem(label: 'Copy', enabled: false),
        _MenuItem(label: 'Paste', enabled: false),
      ];
    }
    if (menu == 'View') {
      return const [
        _MenuItem(label: 'by Icon'),
        _MenuItem(label: 'by Name'),
      ];
    }
    return const [
      _MenuItem(label: 'About This Demo…'),
    ];
  }
}

// Helper to run a callback after layout.
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

// ===== Data & Icon widget =====
class _DesktopItem {
  _DesktopItem({
    required this.id,
    required this.type,
    required this.title,
    required this.position,
    this.content,
  });

  final int id;
  final _IconType type;
  final String title;
  Offset position; // in desktop local coordinates
  String? content;
  bool selected = false;
  final key = GlobalKey<_IconWidgetState>();
}

enum _IconType { note, doc, floppy }

class _IconWidget extends StatefulWidget {
  const _IconWidget({
    required this.item,
    required this.desktopSize,
    required this.onDoubleTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onEndDrag,
    required this.dragActive,
    super.key,
  });

  final _DesktopItem item;
  final Size desktopSize;
  final VoidCallback onDoubleTap;
  final void Function(Rect rectGlobal) onBeginDrag;
  final void Function(Offset globalDelta) onDragUpdate;
  final VoidCallback onEndDrag;
  final bool dragActive;

  @override
  State<_IconWidget> createState() => _IconWidgetState();
}

class _IconWidgetState extends State<_IconWidget> {
  final _iconKey = GlobalKey();
  late Offset _dragStartGlobal;

  Rect? _globalRect() {
    final box = _iconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final pos = item.position;

    final iconPainter = switch (item.type) {
      _IconType.note => const _DocumentIconPainter(),
      _IconType.doc => const _DocumentIconPainter(fold: false),
      _IconType.floppy => const _FloppyIconPainter(),
    };

    final icon = RepaintBoundary(
      key: _iconKey,
      child: Opacity(
        opacity: widget.dragActive ? 0.25 : 1.0, // dim while dragging outline
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: const Size(44, 44), painter: iconPainter),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: item.selected ? Colors.black : Colors.transparent,
                border: Border.all(),
              ),
              child: Text(
                item.title,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: item.selected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final body = GestureDetector(
      onTap: () => setState(() => item.selected = !item.selected),
      onDoubleTap: widget.onDoubleTap,
      onPanStart: (d) {
        _dragStartGlobal = d.globalPosition;
        final r = _globalRect();
        if (r != null) widget.onBeginDrag(r);
      },
      onPanUpdate: (d) {
        final delta = d.globalPosition - _dragStartGlobal;
        _dragStartGlobal = d.globalPosition;
        widget.onDragUpdate(delta);
      },
      onPanEnd: (_) => widget.onEndDrag(),
      child: icon,
    );

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: body,
    );
  }
}

// Anchored non-interactive icon used for right-side column
class _StaticIcon extends StatelessWidget {
  const _StaticIcon({required this.type, required this.label});
  final _IconType type;
  final String label;
  @override
  Widget build(BuildContext context) {
    final painter = switch (type) {
      _IconType.note => const _DocumentIconPainter(),
      _IconType.doc => const _DocumentIconPainter(fold: false),
      _IconType.floppy => const _FloppyIconPainter(),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(44, 44), painter: painter),
        const SizedBox(height: 6),
        _IconLabel(label),
      ],
    );
  }
}

// ===== Menu bar =====
class _System1MenuBar extends StatelessWidget {
  const _System1MenuBar({required this.onOpenMenu});
  final void Function(String menu) onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8E8E8),
      child: Container(
        height: 28,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide()),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            _menuButton('Apple', ''),
            const SizedBox(width: 14),
            _menuButton('File', 'File'),
            _menuButton('Edit', 'Edit'),
            _menuButton('View', 'View'),
            _menuButton('Special', 'Special'),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String key, String label) {
    return GestureDetector(
      onTap: () => onOpenMenu(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.transparent,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFEFEF),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          border: Border.all(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({required this.label, this.onTap, this.enabled = true});
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: widget.enabled
          ? (_hover ? Colors.white : Colors.black)
          : Colors.black26,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          color: _hover && widget.enabled ? Colors.black : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}

class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: Colors.black,
    margin: const EdgeInsets.symmetric(vertical: 2),
  );
}

// ===== Trash (fixed) =====
class _TrashIcon extends StatelessWidget {
  const _TrashIcon({super.key, this.highlight = false});
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(44, 44),
          painter: _TrashPainter(highlight: highlight),
        ),
        const SizedBox(height: 6),
        const _IconLabel('Trash'),
      ],
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

// ===== Windows =====
class _NoteWindow extends StatelessWidget {
  const _NoteWindow({
    required this.title,
    required this.content,
    required this.onClose,
  });
  final String title;
  final String content;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          border: Border.all(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(title: title, onClose: onClose),
            Container(height: 1, color: Colors.black),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotePadWindow extends StatefulWidget {
  const _NotePadWindow({required this.onClose, required this.onSaveToDesktop});
  final VoidCallback onClose;
  final void Function(String text) onSaveToDesktop;
  @override
  State<_NotePadWindow> createState() => _NotePadWindowState();
}

class _NotePadWindowState extends State<_NotePadWindow> {
  String _text = '';
  int _typed = 0;
  final String _auto = 'Buy milk';

  @override
  void initState() {
    super.initState();
    // Auto-type for the presentation
    _typeNext();
  }

  Future<void> _typeNext() async {
    if (_typed >= _auto.length) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      _text += _auto[_typed];
      _typed++;
    });
    unawaited(_typeNext());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 460,
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          border: Border.all(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(
              title: 'Note Pad',
              onClose: widget.onClose,
              striped: true,
            ),
            Container(height: 1, color: Colors.black),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                child: Text(
                  'Up to eight pages of notes\n\n$_text',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: Stack(
                children: [
                  // dog-ear
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: CustomPaint(
                      size: const Size(24, 16),
                      painter: _DogEarPainter(),
                    ),
                  ),
                  // page number
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Text(
                          '1',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                  // Fake button: Save to Desktop
                  Positioned(
                    right: 8,
                    bottom: 6,
                    child: GestureDetector(
                      onTap: () => widget.onSaveToDesktop(_text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(),
                        ),
                        child: const Text(
                          'Save to Desktop',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.onClose,
    this.striped = false,
  });
  final String title;
  final VoidCallback onClose;
  final bool striped;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: const Color(0xFFE3E3E3),
      child: Stack(
        children: [
          if (striped)
            Positioned.fill(
              child: CustomPaint(painter: _StripePainter()),
            ),
          Row(
            children: [
              const SizedBox(width: 6),
              Container(width: 12, height: 12, color: Colors.black),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontFamily: 'monospace')),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    border: Border.all(),
                  ),
                  child: const Center(
                    child: Text('×', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== Painters for icons & background =====
class _DitheredBackground extends StatelessWidget {
  const _DitheredBackground();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DitherPainter(),
    );
  }
}

class _DitherPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFE8E8E8);
    canvas.drawRect(Offset.zero & size, light);

    // Simple 2x2 halftone dots
    final dot = Paint()..color = Colors.black.withValues(alpha: .08);
    const spacing = 6.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (
        // ignore: omit_local_variable_types
        double x = (y ~/ spacing).isEven ? 0 : spacing / 2;
        x < size.width;
        x += spacing
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocumentIconPainter extends CustomPainter {
  const _DocumentIconPainter({this.fold = true});
  final bool fold;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    // Outline
    canvas.drawRect(
      Rect.fromLTWH(8, 4, s.width - 16, s.height - 8),
      p..style = PaintingStyle.stroke,
    );
    if (fold) {
      // small dog-ear fold
      canvas
        ..drawLine(const Offset(28, 4), const Offset(40, 4), p)
        ..drawLine(const Offset(40, 4), const Offset(40, 16), p);
    }
    // text lines
    for (var i = 0; i < 4; i++) {
      final dy = 14.0 + i * 6;
      canvas.drawLine(Offset(12, dy), Offset(s.width - 12, dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloppyIconPainter extends CustomPainter {
  const _FloppyIconPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    // body
    canvas
      ..drawRect(
        Rect.fromLTWH(6, 6, s.width - 12, s.height - 12),
        p..style = PaintingStyle.stroke,
      )
      // shutter
      ..drawRect(Rect.fromLTWH(12, 10, s.width - 24, 10), p)
      // label
      ..drawRect(
        Rect.fromLTWH(12, 26, s.width - 24, 10),
        p..style = PaintingStyle.stroke,
      )
      // notch
      ..drawRect(const Rect.fromLTWH(10, 36, 4, 6), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrashPainter extends CustomPainter {
  const _TrashPainter({this.highlight = false});
  final bool highlight;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    // can outline
    final r = Rect.fromLTWH(12, 8, s.width - 24, s.height - 16);
    if (highlight) {
      // Invert look a little when highlighted
      canvas.drawRect(r, p);
      final inner = Paint()..color = const Color(0xFFEFEFEF);
      canvas.drawRect(Rect.fromLTWH(8, 4, s.width - 16, 4), inner);
    } else {
      canvas
        ..drawRect(r, p..style = PaintingStyle.stroke)
        ..drawRect(
          Rect.fromLTWH(8, 4, s.width - 16, 4),
          p..style = PaintingStyle.fill,
        );
    }
    // ribs
    for (var x = r.left + 6; x < r.right - 2; x += 6) {
      if (highlight) {
        canvas.drawLine(
          Offset(x, r.top + 2),
          Offset(x, r.bottom - 2),
          Paint()..color = const Color(0xFFEFEFEF),
        );
      } else {
        canvas.drawLine(Offset(x, r.top + 2), Offset(x, r.bottom - 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: .25);
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DogEarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black;
    final path = Path()
      ..moveTo(0, s.height)
      ..lineTo(s.width, s.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, p..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== Drag outline painter =====
class _DragOutlinePainter extends CustomPainter {
  _DragOutlinePainter({required this.rectLocal, required this.phase});
  final Rect rectLocal;
  final double phase; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final r = rectLocal;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw marching ants dashed rectangle
    _drawDashedRect(canvas, r, paint, phase);
  }

  void _drawDashedRect(Canvas c, Rect r, Paint p, double phase) {
    const dash = 6.0; // on+off length
    final offset = (phase * dash * 2) % (dash * 2);

    void h(double y, double x1, double x2) {
      for (var x = x1 - offset; x < x2; x += dash * 2) {
        final xStart = x.clamp(x1, x2);
        final xEnd = (x + dash).clamp(x1, x2);
        if (xEnd > xStart) c.drawLine(Offset(xStart, y), Offset(xEnd, y), p);
      }
    }

    void v(double x, double y1, double y2) {
      for (var y = y1 - offset; y < y2; y += dash * 2) {
        final yStart = y.clamp(y1, y2);
        final yEnd = (y + dash).clamp(y1, y2);
        if (yEnd > yStart) c.drawLine(Offset(x, yStart), Offset(x, yEnd), p);
      }
    }

    h(r.top, r.left, r.right);
    h(r.bottom, r.left, r.right);
    v(r.left, r.top, r.bottom);
    v(r.right, r.top, r.bottom);
  }

  @override
  bool shouldRepaint(covariant _DragOutlinePainter old) =>
      old.rectLocal != rectLocal || old.phase != phase;
}
