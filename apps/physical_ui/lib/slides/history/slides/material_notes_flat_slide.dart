import 'dart:async';
import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wnma_talk/wnma_talk.dart';

// =================== Riverpod ===================

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

  void add(String text) => state = [text, ...state];
  void removeAt(int index) {
    if (index >= 0 && index < state.length) {
      final newList = [...state]..removeAt(index);
      state = newList;
    }
  }
}

// =================== Slide ===================

/// 2010s: Flat Design & Material – Notes flow
/// Flow:
/// + (FAB) -> bottom sheet editor -> auto-types "Buy milk" -> closes ->
/// deletes first item
class MaterialNotesFlatSlide extends FlutterDeckSlideWidget {
  const MaterialNotesFlatSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/history/flat/material-notes',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (_) => const _DeviceFramedDemo(),
    );
  }
}

// =================== Device frame ===================

class _DeviceFramedDemo extends StatelessWidget {
  const _DeviceFramedDemo();

  // A clean, generic modern phone frame (no skeuomorphic chrome)
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
        // ignore: lines_longer_than_80_chars
        screen: const ProviderScope(
          child: MaterialApp(home: _NotesDemoScreen()),
        ),
      ),
    );
  }
}

class _NotesDemoScreen extends HookConsumerWidget {
  const _NotesDemoScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final hasAutoplayRun = useState(false);

    // Auto-play the scripted interaction once.
    useEffect(() {
      if (hasAutoplayRun.value) return null;
      hasAutoplayRun.value = true;

      Future.microtask(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (context.mounted) {
          final created = await _openEditorAndType(
            context,
            initial: 'Buy milk',
          );
          if (created != null && created.trim().isNotEmpty) {
            ref.read(notesProvider.notifier).add(created.trim());
          }
          // Give the list a beat to settle, then "swipe-delete" top item.
          await Future<void>.delayed(const Duration(milliseconds: 800));
          ref.read(notesProvider.notifier).removeAt(0);
        }
      });

      return null;
    }, const []);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2962FF), // bold, print-like color
        brightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text(
            'Notes',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: notes.length,
          itemBuilder: (context, i) {
            final note = notes[i];
            return Dismissible(
              key: ValueKey('n-$i-$note'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => ref.read(notesProvider.notifier).removeAt(i),
              background: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.delete, size: 28, color: Colors.red[700]),
                ),
              ),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: false,
                  title: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('Tap to edit • Swipe to delete'),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag:
              'material-notes-fab', // any unique Object or String; optional
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

// =================== Editor (Material bottom sheet) ===================

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
    final controller = useTextEditingController(text: '');
    final t = useRef<Timer?>(null);

    // Auto-type, but DO NOT close automatically.
    useEffect(() {
      t.value = Timer.periodic(const Duration(milliseconds: 60), (timer) {
        final curr = controller.text;
        if (curr.length >= initial.length) {
          timer.cancel();
        } else {
          controller..text = curr + initial[curr.length]
          ..selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
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
            subtitle: Text('Material bottom sheet • Content over chrome'),
          ),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type your note…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {}, // no-op; only Save closes
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
                onPressed: () =>
                    Navigator.of(context).pop<String>(controller.text),
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
