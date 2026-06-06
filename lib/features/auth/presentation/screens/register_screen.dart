import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../common_widgets/app_button.dart';
import '../../../../common_widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_error_l10n.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_brand_mark.dart';
import '../widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(8),
                const AuthBrandMark(),
                const Gap(32),
                Text(
                  l10n.registerTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: t.textPrimary,
                  ),
                ),
                const Gap(8),
                Text(
                  l10n.registerSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: t.textSecondary,
                  ),
                ),
                const Gap(32),
                if (auth.status == AuthStatus.unauthenticated &&
                    auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer, size: 18),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            localizedAuthError(l10n, auth.error),
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                ],
                AppTextField(
                  label: l10n.fieldFullName,
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.validationNameRequired;
                    }
                    return null;
                  },
                ),
                const Gap(14),
                AppTextField(
                  label: l10n.fieldEmail,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.validationEmailRequired;
                    }
                    if (!v.contains('@')) return l10n.validationEmailInvalid;
                    return null;
                  },
                ),
                const Gap(14),
                AppTextField(
                  label: l10n.fieldPassword,
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.validationPasswordRequired;
                    }
                    if (v.length < 6) return l10n.validationPasswordMin;
                    return null;
                  },
                ),
                const Gap(14),
                AppTextField(
                  label: l10n.fieldConfirmPassword,
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v != _passwordCtrl.text) {
                      return l10n.validationPasswordMismatch;
                    }
                    return null;
                  },
                ),
                const Gap(28),
                AppButton(
                  label: l10n.buttonCreateAccount,
                  loading: isLoading,
                  onPressed: _submit,
                ),
                const Gap(20),
                const GoogleSignInButton(),
                const Gap(16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: RichText(
                      text: TextSpan(
                        text: l10n.registerHaveAccount,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: t.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: l10n.buttonSignIn,
                            style: GoogleFonts.inter(
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
