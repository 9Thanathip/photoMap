import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Liquid-glass modal sheet chrome: backdrop blur under a translucent
/// surface with a hairline top border. Wrap a sheet's content in this
/// instead of a solid-surface Container so every sheet in the app shares
/// the same iOS-style glass look.
///
/// Pair with `showModalBottomSheet(backgroundColor: Colors.transparent,
/// isScrollControlled: true, ...)` — the transparent host lets the blur
/// sample the screen behind the sheet.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.topRadius = 24,
  });

  final Widget child;
  final double topRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.vertical(top: Radius.circular(topRadius));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface
                .withValues(alpha: isDark ? 0.72 : 0.8),
            borderRadius: radius,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
