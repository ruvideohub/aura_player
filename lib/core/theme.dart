import 'package:flutter/material.dart';

class AccentOption {
  final String label;
  final Color color;

  const AccentOption(this.label, this.color);
}

/// Те же пять акцентов, что и в веб-версии AURA.
const List<AccentOption> accents = [
  AccentOption('Янтарь', Color(0xFFF59E0B)),
  AccentOption('Изумруд', Color(0xFF10B981)),
  AccentOption('Роза', Color(0xFFF43F5E)),
  AccentOption('Фиалка', Color(0xFF8B5CF6)),
  AccentOption('Пламя', Color(0xFFFB923C)),
];

ThemeData buildTheme(Brightness brightness, Color accent) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(seedColor: accent, brightness: brightness);

  final background = isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF6F5F2);
  final surface = isDark ? const Color(0xFF141420) : Colors.white;
  final outline = isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.06);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      primary: accent,
      secondary: accent,
      surface: surface,
      surfaceContainerHighest:
          isDark ? const Color(0xFF1C1C28) : const Color(0xFFECEBE6),
    ),
    scaffoldBackgroundColor: background,
    dividerColor: outline,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      thumbColor: accent,
      activeTrackColor: accent,
      inactiveTrackColor: isDark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.10),
      overlayColor: accent.withOpacity(0.15),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: outline),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    visualDensity: VisualDensity.comfortable,
  );
}
