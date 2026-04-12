import 'package:flutter/material.dart';

/// A standard widget for displaying empty states with an icon and text.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.showLoader = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLoader)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: CircularProgressIndicator(color: theme.colorScheme.primary),
              )
            else
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.2),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
