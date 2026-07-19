import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Dedicated profile screen — shows the signed-in identity clearly and
/// hosts account actions. Destructive actions live one level deeper
/// (see [DeleteAccountScreen]) so they can't be tapped by accident.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authNotifierProvider);
    final t = context.tokens;

    final email = auth.email ?? '';
    final name = (auth.displayName?.trim().isNotEmpty ?? false)
        ? auth.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : l10n.defaultUserName);
    final verified = auth.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      appBar: AppBar(
        backgroundColor: t.surfaceBase,
        title: Text(
          l10n.profileTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _ProfileHeader(name: name, email: email, verified: verified),
          const SizedBox(height: 28),

          _SectionLabel(l10n.sectionAccount),
          const SizedBox(height: 10),
          _Card(
            children: [
              _ActionTile(
                icon: AppIcons.verified_user_outlined,
                iconColor: t.textPrimary,
                title: l10n.profileAccountStatus,
                trailing: Text(
                  verified ? l10n.profileVerified : l10n.profileUnverified,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: verified ? t.textPrimary : t.textSecondary,
                  ),
                ),
              ),
              _Divider(),
              _ActionTile(
                icon: AppIcons.logout_rounded,
                iconColor: t.textSecondary,
                title: l10n.profileSignOut,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 28),

          _SectionLabel(l10n.sectionDangerZone),
          const SizedBox(height: 10),
          _Card(
            children: [
              _ActionTile(
                icon: AppIcons.manage_accounts_outlined,
                iconColor: t.textSecondary,
                title: l10n.profileManageAccount,
                subtitle: l10n.profileManageAccountSubtitle,
                onTap: () => context.push('/profile/delete-account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.verified,
  });

  final String name;
  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.goldGrad,
            ),
          ),
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: t.textOnAccent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: t.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (verified ? t.textPrimary : t.textSecondary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                verified ? AppIcons.check_circle_rounded : AppIcons.error_outline,
                size: 14,
                color: verified ? t.textPrimary : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                verified
                    ? AppLocalizations.of(context).profileVerifiedAccount
                    : AppLocalizations.of(context).profileUnverified,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: verified ? t.textPrimary : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared bits (mirror settings styling) ──────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: context.tokens.textSecondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(
                AppIcons.chevron_right_rounded,
                size: 18,
                color: t.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 0,
      color: context.tokens.dividerSoft,
    );
  }
}
