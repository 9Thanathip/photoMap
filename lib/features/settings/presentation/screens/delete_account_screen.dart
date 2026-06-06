import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Buried one level under [ProfileScreen]. Account deletion is gated behind
/// an explicit acknowledgement checkbox *and* a final confirm dialog, so it
/// takes deliberate intent — three taps minimum — to trigger.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.status == AuthStatus.loading),
    );

    final consequences = [
      l10n.deleteConsequencePhotos,
      l10n.deleteConsequenceAchievements,
      l10n.deleteConsequencePermanent,
    ];

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        title: Text(
          l10n.profileManageAccount,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.accentCoral.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: t.accentCoral,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.deleteAccountTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.deleteAccountIntro,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: t.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.borderSubtle),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < consequences.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: t.accentCoral,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          consequences[i],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _acknowledged,
                    activeColor: t.accentCoral,
                    onChanged: (v) =>
                        setState(() => _acknowledged = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      l10n.deleteAccountAcknowledge,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.accentCoral,
                disabledBackgroundColor: t.accentCoral.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (!_acknowledged || isLoading)
                  ? null
                  : () => _confirmDelete(context),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.deleteAccountButton,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                l10n.commonCancel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.accentCoral,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).deleteAccount();
            },
            child: Text(l10n.deleteConfirmAction),
          ),
        ],
      ),
    );
  }
}
