import 'dart:ui';

import 'package:flutter/material.dart';

/// Стеклянная панель (glassmorphism) — сайдбар, тайтлбар, оверлеи.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 18,
    this.padding,
    this.borderRadius,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ??
                (isDark
                    ? Colors.black.withOpacity(0.45)
                    : Colors.white.withOpacity(0.60)),
            borderRadius: r,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
