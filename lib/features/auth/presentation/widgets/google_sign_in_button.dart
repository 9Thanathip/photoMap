import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../common_widgets/app_button.dart';
import '../providers/auth_provider.dart';

/// "or" divider + Continue with Google button, shared by login/register.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.status == AuthStatus.loading),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: theme.dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.dividerColor)),
          ],
        ),
        const Gap(16),
        AppButton(
          label: 'Continue with Google',
          outlined: true,
          icon: Icons.account_circle_outlined,
          loading: isLoading,
          onPressed: () =>
              ref.read(authNotifierProvider.notifier).signInWithGoogle(),
        ),
      ],
    );
  }
}
