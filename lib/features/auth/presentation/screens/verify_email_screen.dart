import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../common_widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_error_l10n.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldown = Duration(seconds: 30);

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Silently re-check every few seconds so the screen advances on its
    // own once the user clicks the link in their inbox.
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => ref.read(authNotifierProvider.notifier).refreshVerification(),
    );
    _startCooldown();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _resendCooldown.inSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final verified =
        await ref.read(authNotifierProvider.notifier).refreshVerification();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!verified) {
      _snack(AppLocalizations.of(context).verifyNotVerifiedYet);
    }
  }

  Future<void> _resend() async {
    final err =
        await ref.read(authNotifierProvider.notifier).resendVerification();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (err == null) {
      _startCooldown();
      _snack(l10n.verifyEmailSent);
    } else {
      _snack(localizedAuthError(l10n, err));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = ref.watch(
      authNotifierProvider.select((s) => s.email),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(48),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const Gap(24),
              Text(
                l10n.verifyTitle,
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const Gap(12),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(text: l10n.verifyBodyPrefix),
                    TextSpan(
                      text: email ?? l10n.verifyYourEmail,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: l10n.verifyBodySuffix),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: l10n.verifyContinue,
                loading: _checking,
                onPressed: _check,
              ),
              const Gap(12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cooldown == 0 ? _resend : null,
                  child: Text(
                    _cooldown == 0
                        ? l10n.verifyResend
                        : l10n.verifyResendCooldown(_cooldown),
                  ),
                ),
              ),
              const Gap(4),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).signOut(),
                  child: Text(
                    l10n.verifyUseAnotherAccount,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}
