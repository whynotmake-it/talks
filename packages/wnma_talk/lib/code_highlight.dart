import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:wnma_talk/wnma_talk.dart';

class CodeHighlight extends StatelessWidget {
  const CodeHighlight({
    required this.code,
    this.filename,
    super.key,
  });

  final String? filename;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      clipBehavior: Clip.hardEdge,
      color: vs2015Theme['root']!.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filename case final filename?) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                filename,
                style:
                    FlutterDeckTheme.of(
                      context,
                    ).textTheme.bodySmall.copyWith(
                      color: vs2015Theme['root']!.color,
                    ),
              ),
            ),
            const Divider(
              height: 1,
              color: Colors.white24,
            ),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: HighlightView(
                code,
                padding: const EdgeInsets.all(24),
                textStyle: FlutterDeckTheme.of(
                  context,
                ).codeHighlightTheme.textStyle,
                language: 'dart',
                theme: vs2015Theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
