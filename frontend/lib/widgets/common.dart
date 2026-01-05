import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  // Opsiyoneller
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry? padding;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final child = padding != null ? Padding(padding: padding!, child: body) : body;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: bottom,
      ),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

// Küçük yardımcılar (opsiyonel)

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class Dot extends StatelessWidget {
  const Dot({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.outline,
      shape: BoxShape.circle,
    ),
  );
}
