import 'package:flutter/material.dart';

/// A standard bottom sheet handle with an optional title.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key, this.title, this.padding});

  final String? title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null)
          Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
