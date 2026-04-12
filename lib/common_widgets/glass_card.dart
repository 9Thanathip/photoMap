import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A premium glassmorphic container with blur and subtle borders.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.borderRadius = 16,
    this.sigma = 12,
    this.opacity = 0.7,
    this.borderOpacity = 0.3,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final double sigma;
  final double opacity;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: opacity * 0.15)
        : Colors.white.withValues(alpha: opacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: borderOpacity * 0.4)
        : Colors.white.withValues(alpha: borderOpacity);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.25 : 0.07);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
