import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

class CitationContainer extends StatelessWidget {
  const CitationContainer({
    required this.citation,
    this.fontSize = 16,
    super.key,
  });

  final String citation;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
        ),
        child: Text(
          citation,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}