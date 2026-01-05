import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
