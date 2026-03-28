import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    required this.sub,
    this.showSpinner = false,
  });

  final String message;
  final String sub;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner)
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            )
          else
            Icon(Icons.photo_library_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128)),
          const Gap(16),
          Text(message,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (sub.isNotEmpty) ...[
            const Gap(8),
            Text(sub,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outlineVariant)),
          ],
        ],
      ),
    );
  }
}
