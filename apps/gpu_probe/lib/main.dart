import 'package:flutter/cupertino.dart';

void main() => runApp(const GpuProbeApp());

/// The profiling probe from the build_to_burn hook: the talk's demo screen
/// (a blue page with two circles) and a Cupertino alert with a search field
/// pushed over it.
class GpuProbeApp extends StatelessWidget {
  const GpuProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CirclesScreen(),
    );
  }
}

/// The talk's blue page with its two circles, plus a button that pushes the
/// iOS-style alert over them.
class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

  static const _blue = Color(0xFF2563EB);
  static const _circle = Color(0xFF93C5FD);

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: _blue),
          Positioned(left: 40, top: 170, child: _Circle(size: 150)),
          Positioned(right: 50, top: 470, child: _Circle(size: 120)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Center(child: _AlertButton()),
          ),
        ],
      ),
    );
  }
}

/// Pushes a Cupertino alert with a search field over the blurred circles.
/// The field starts unfocused; tap it to bring up the keyboard and cursor.
class _AlertButton extends StatelessWidget {
  const _AlertButton();

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(
      onPressed: () => _showSearchAlert(context),
      child: const Text('Show alert'),
    );
  }

  void _showSearchAlert(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Search'),
        content: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoTextField(placeholder: 'Type to search'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: CirclesScreen._circle,
        shape: BoxShape.circle,
      ),
    );
  }
}
