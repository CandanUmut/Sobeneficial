import 'package:flutter/material.dart';

class Skeleton extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius radius;
  const Skeleton({super.key, this.height = 14, this.width = double.infinity, this.radius = const BorderRadius.all(Radius.circular(12))});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: radius,
      ),
      height: height,
      width: width,
    );
  }
}
