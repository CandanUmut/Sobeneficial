import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onAvatarTap;
  const AppHeader({super.key, required this.title, this.onSearch, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Search best practices, RFH, people…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(onPressed: onAvatarTap, icon: const CircleAvatar(child: Icon(Icons.person))),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
