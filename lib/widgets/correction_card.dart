import 'package:flutter/material.dart';

import '../models/message.dart';

class CorrectionCard extends StatelessWidget {
  const CorrectionCard({super.key, required this.change});
  final GrammarChange change;

  @override
  Widget build(BuildContext context) {
    final tint = _categoryTint(change.category);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(change.category), size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                _categoryLabel(change.category),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: tint, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: change.original,
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                const TextSpan(text: '  →  '),
                TextSpan(
                  text: change.corrected,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change.explanation,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Color _categoryTint(String c) {
    switch (c) {
      case 'punctuation':
        return Colors.teal;
      case 'structure':
        return Colors.indigo;
      case 'tone':
        return Colors.purple;
      case 'spelling':
        return Colors.orange;
      case 'fact':
        return Colors.red;
      case 'grammar':
      default:
        return Colors.blue;
    }
  }

  IconData _categoryIcon(String c) {
    switch (c) {
      case 'punctuation':
        return Icons.format_quote;
      case 'structure':
        return Icons.short_text;
      case 'tone':
        return Icons.tune;
      case 'spelling':
        return Icons.spellcheck;
      case 'fact':
        return Icons.warning_amber;
      case 'grammar':
      default:
        return Icons.auto_fix_high;
    }
  }

  String _categoryLabel(String c) {
    if (c.isEmpty) return 'Grammar';
    return c[0].toUpperCase() + c.substring(1);
  }
}
