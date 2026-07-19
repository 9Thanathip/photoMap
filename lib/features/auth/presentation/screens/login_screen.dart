import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../common_widgets/app_button.dart';
import '../../../../common_widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_error_l10n.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(40),
                const AuthBrandMark(),
                const Gap(36),
                Text(
                  l10n.loginWelcomeBack,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: t.textPrimary,
                  ),
                ),
                const Gap(8),
                Text(
                  l10n.loginSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: t.textSecondary,
                  ),
                ),
                const Gap(36),
                if (auth.status == AuthStatus.unauthenticated &&
                    auth.error != null) ...[
                  _ErrorBanner(message: localizedAuthError(l10n, auth.error)),
                  const Gap(16),
                ],
                AppTextField(
                  label: l10n.fieldEmail,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(AppIcons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.validationEmailRequired;
                    }
                    if (!v.contains('@')) return l10n.validationEmailInvalid;
                    return null;
                  },
                ),
                const Gap(16),
                AppTextField(
                  label: l10n.fieldPassword,
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(AppIcons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? AppIcons.visibility_off_outlined
                          : AppIcons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.validationPasswordRequired;
                    }
                    return null;
                  },
                ),
                const Gap(28),
                AppButton(
                  label: l10n.buttonSignIn,
                  loading: isLoading,
                  onPressed: _submit,
                ),
                const Gap(20),
                const GoogleSignInButton(),
                const Gap(16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/register'),
                    child: RichText(
                      text: TextSpan(
                        text: l10n.loginNoAccount,
                        style: TextStyle(
                          fontSize: 14,
                          color: t.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: l10n.buttonRegister,
                            style: TextStyle(
                              fontSize: 14,
                              color: t.accentGoldDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.error_outline,
              color: theme.colorScheme.onErrorContainer, size: 18),
          const Gap(8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
