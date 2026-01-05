import 'package:flutter/material.dart';

class AppTheme {
  static const _brand = Colors.teal;

  static ThemeData light() {
    final color = ColorScheme.fromSeed(seedColor: _brand);
    return ThemeData(
      colorScheme: color,
      useMaterial3: true,
      scaffoldBackgroundColor: color.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: color.surface,
        foregroundColor: color.onSurface,
        centerTitle: false,
      ),
      // 🔧 SDK'nız CardThemeData beklediği için CardThemeData kullandık
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        isDense: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final color = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.dark,
    );
    // light() üstüne koyarak tutarlılık sağlıyoruz
    final base = light();
    return base.copyWith(
      colorScheme: color,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: color.surface,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: color.surface,
        foregroundColor: color.onSurface,
      ),
    );
  }
}

/// Küçük tasarım sabitleri
class G {
  static const r = 16.0; // radius
  static const s = 12.0; // spacing
  static const l = 24.0; // large spacing
}
