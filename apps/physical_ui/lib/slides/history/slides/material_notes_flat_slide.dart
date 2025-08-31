// drop-in replacement for MaterialNotesFlatSlide.dart (single file)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

// -------- State --------
final notesProvider = StateNotifierProvider<_NotesController, List<String>>((
  ref,
) {
  return _NotesController([
    'Window measurements',
    'Groceries',
    'Birthday ideas',
    'Trip packing list',
  ]);
});

class _NotesController extends StateNotifier<List<String>> {
  _NotesController(super.initial);
  void add(String t) => state = [t, ...state];
  void removeAt(int i) {
    if (i >= 0 && i < state.length) state = [...state]..removeAt(i);
  }
}

// -------- Slide (3 steps: 0 app → 1 windows → 2 iOS) --------
class MaterialNotesFlatSlide extends FlutterDeckSlideWidget {
  const MaterialNotesFlatSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/material-notes',
          steps: 3, // 0: run app demo, 1: show Windows, 2: show iOS
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, step) => Stack(
          children: [
            _DeviceFramedDemo(
              step: step,
            ), // app is always visible; auto-demo only on step 0
            Positioned.fill(child: _FlatGallery(step: step)),
          ],
        ),
      ),
    );
  }
}

// -------- Before/After gallery overlay --------
class _FlatGallery extends StatelessWidget {
  const _FlatGallery({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final showWin = step >= 2;
    final showIOS = step >= 3;
    return Stack(
      children: [
        AnimatedOpacity(
          duration: kThemeAnimationDuration,
          opacity: showWin ? 1 : 0,
          child: SizedBox.expand(
            child: ColoredBox(
              color: FlutterDeckTheme.of(
                context,
              ).materialTheme.scaffoldBackgroundColor,
            ),
          ),
        ),
        SizedBox.expand(
          child: Padding(
            padding: EdgeInsetsGeometry.all(32),
            child: _PairRow(
              visible: showWin,
              left: 'assets/history/windows7.webp',
              right: 'assets/history/windows8.jpg',
              leftFrom: const Offset(-1200, -40),
              rightFrom: const Offset(1200, -40),
            ),
          ),
        ),
        const SizedBox(height: 64),
        Positioned.fill(
          child: Stack(
            children: [
              AnimatedOpacity(
                opacity: showIOS ? 1 : 0,
                duration: kThemeAnimationDuration,
                child: SizedBox.expand(
                  child: ColoredBox(
                    color: FlutterDeckTheme.of(
                      context,
                    ).materialTheme.scaffoldBackgroundColor,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.all(32),
                  child: Row(
                    spacing: 32,
                    children: [
                      Expanded(
                        child: _PairRow(
                          visible: showIOS,
                          left: 'assets/history/ios6_home.png',
                          right: 'assets/history/ios7_home.png',
                          leftFrom: const Offset(0, -1200),
                          rightFrom: const Offset(0, -1200),
                          stagger: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PairRow(
                          visible: showIOS,
                          left: 'assets/history/ios6_calc.png',
                          right: 'assets/history/ios7_calc.png',
                          leftFrom: const Offset(0, -1200),
                          rightFrom: const Offset(0, -1200),
                          stagger: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.visible,

    required this.left,
    required this.right,
    this.leftFrom = const Offset(-800, 0),
    this.rightFrom = const Offset(800, 0),
    this.stagger = 0,
  });
  final bool visible;

  final String left;
  final String right;
  final Offset leftFrom;
  final Offset rightFrom;
  final int stagger;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 520) +
          Duration(milliseconds: 80 * stagger),
    );
    return Row(
      children: [
        Expanded(
          child: _FlyInCard(
            asset: left,
            from: visible ? Offset.zero : leftFrom,
            rotFrom: visible ? 0 : -.06,
            motion: motion,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FlyInCard(
            asset: right,
            from: visible ? Offset.zero : rightFrom,
            rotFrom: visible ? 0 : .06,
            motion: motion,
          ),
        ),
      ],
    );
  }
}

class _FlyInCard extends StatelessWidget {
  const _FlyInCard({
    required this.asset,
    required this.from,
    required this.rotFrom,
    required this.motion,
  });
  final String asset;
  final Offset from;
  final double rotFrom;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder<Offset>(
      value: from,
      motion: motion,
      converter: OffsetMotionConverter(),
      builder: (_, off, child) => Transform.translate(
        offset: off,
        child: SingleMotionBuilder(
          value: rotFrom,
          motion: motion,
          builder: (_, a, child) => Transform.rotate(angle: a, child: child),
          child: child,
        ),
      ),
      child: Material(
        elevation: 10,
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}

// -------- Device demo (auto-runs only at step 0) --------
class _DeviceFramedDemo extends StatelessWidget {
  const _DeviceFramedDemo({required this.step});
  final int step;

  static final DeviceInfo _modernPhone = DeviceInfo.genericPhone(
    platform: TargetPlatform.android,
    name: 'Modern Android',
    id: 'modern-android',
    screenSize: const Size(360, 760),
    pixelRatio: 3,
    safeAreas: const EdgeInsets.only(top: 24, bottom: 24),
    rotatedSafeAreas: const EdgeInsets.only(left: 24, right: 24),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DeviceFrame(
        device: _modernPhone,
        screen: ProviderScope(
          child: ExcludeFocus(
            child: MaterialApp(home: _NotesDemoScreen(runDemo: step == 0)),
          ),
        ),
      ),
    );
  }
}

class _NotesDemoScreen extends HookConsumerWidget {
  const _NotesDemoScreen({required this.runDemo});
  final bool runDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final ran = useState(false);

    useEffect(() {
      if (!runDemo || ran.value) return null;
      ran.value = true;
      Future.microtask(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        final created = await _openEditorAndType(context, initial: 'Buy milk');
        if (created != null && created.trim().isNotEmpty) {
          ref.read(notesProvider.notifier).add(created.trim());
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
        ref.read(notesProvider.notifier).removeAt(0);
      });
      return null;
    }, [runDemo]);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2962FF),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Notes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: notes.length,
          itemBuilder: (context, i) => Dismissible(
            key: ValueKey('n-$i-${notes[i]}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => ref.read(notesProvider.notifier).removeAt(i),
            background: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.delete, size: 28, color: Colors.red),
              ),
            ),
            child: Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(
                  notes[i],
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Tap to edit • Swipe to delete'),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'material-notes-fab',
          onPressed: () async {
            final created = await _openEditorAndType(
              context,
              initial: 'Buy milk',
            );
            if (created != null && created.trim().isNotEmpty) {
              ref.read(notesProvider.notifier).add(created.trim());
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// -------- Bottom sheet (inside device, explicit Save) --------
Future<String?> _openEditorAndType(
  BuildContext context, {
  required String initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EditorSheet(initial: initial),
  );
}

class _EditorSheet extends HookWidget {
  const _EditorSheet({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = useTextEditingController();
    final t = useRef<Timer?>(null);
    useEffect(() {
      t.value = Timer.periodic(const Duration(milliseconds: 60), (k) {
        final curr = c.text;
        if (curr.length >= initial.length) {
          k.cancel();
        } else {
          c
            ..text = curr + initial[curr.length]
            ..selection = TextSelection.collapsed(offset: c.text.length);
        }
      });
      return () => t.value?.cancel();
    }, const []);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'New note',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ),
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type your note…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop<String>(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop<String>(c.text),
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
