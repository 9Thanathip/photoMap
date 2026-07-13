import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import 'google_logo.dart';

/// "or" divider + Continue with Google button, shared by login/register.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.status == AuthStatus.loading),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: t.borderSubtle)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                l10n.authOrDivider,
                style: TextStyle(
                  fontSize: 13,
                  color: t.textSecondary,
                ),
              ),
            ),
            Expanded(child: Divider(color: t.borderSubtle)),
          ],
        ),
        const Gap(20),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () =>
                    ref.read(authNotifierProvider.notifier).signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: t.borderStrong),
              foregroundColor: t.textPrimary,
            ),
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.textSecondary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GoogleLogo(size: 20),
                      const Gap(12),
                      Text(
                        l10n.buttonContinueWithGoogle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
