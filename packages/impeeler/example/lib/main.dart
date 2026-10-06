/// The hook screen of the build_to_burn talk: a feed behind a
/// CupertinoAlertDialog that asks for a name. It looks static, but the
/// dialog's frosted backdrop splits the frame into several render passes,
/// and the focused text field's caret keeps requesting frames.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

void main() => runApp(const HookApp());

class HookApp extends StatelessWidget {
  const HookApp({super.key});

  @override
  Widget build(BuildContext context) => const CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: HookScreen(),
  );
}

class HookScreen extends StatelessWidget {
  const HookScreen({super.key, this.showDialog = true});

  /// Without the dialog the screen is a plain one-pass frame.
  final bool showDialog;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Feed')),
    child: Stack(
      children: [
        ListView.builder(
          itemCount: 30,
          itemBuilder: (context, i) => _Post(index: i),
        ),
        if (showDialog)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(child: _NameDialog()),
          ),
      ],
    ),
  );
}

class _NameDialog extends StatelessWidget {
  const _NameDialog();

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('What should we call you?'),
    content: const Padding(
      padding: EdgeInsets.only(top: 12),
      child: CupertinoTextField(autofocus: true, placeholder: 'Name'),
    ),
    actions: [
      CupertinoDialogAction(onPressed: () {}, child: const Text('Later')),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () {},
        child: const Text('Save'),
      ),
    ],
  );
}

class _Post extends StatelessWidget {
  const _Post({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.primaries[index % Colors.primaries.length],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Post #$index: something worth reading')),
      ],
    ),
  );
}
