import 'package:flutter/material.dart';

class ContentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> tags;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ContentCard({super.key, required this.title, required this.subtitle, this.tags = const [], this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: -8, children: tags.take(6).map((t) => Chip(label: Text(t))).toList()),
                ],
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      ),
    );
  }
}
