import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final t = context.tokens;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 120),
        children: [
          // ── Header ──
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Customize your experience',
            style: GoogleFonts.inter(fontSize: 14, color: t.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Appearance ──
          _SectionLabel('Appearance'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _IconBadge(
                          icon: Icons.palette_outlined,
                          color: t.accentGold,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'App Theme',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ThemeSelector(
                      value: themeMode,
                      onChanged: (m) =>
                          ref.read(themeModeProvider.notifier).setTheme(m),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── General ──
          _SectionLabel('General'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.language_outlined,
                iconColor: t.accentViolet,
                title: 'Language',
                trailing: Text(
                  'English',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: t.textSecondary,
                  ),
                ),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Account ──
          _SectionLabel('Account'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: t.accentGold,
                title: 'Profile',
                subtitle: 'user@example.com',
                onTap: () {},
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: t.textSecondary,
                title: 'Sign Out',
                onTap: () => _confirmSignOut(context, ref),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: t.accentCoral,
                title: 'Delete Account',
                titleColor: t.accentCoral,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── About ──
          _SectionLabel('About'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: t.textSecondary,
                title: 'Version',
                trailing: Text(
                  '1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. All your data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.accentCoral,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).deleteAccount();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: context.tokens.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
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
            _IconBadge(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? t.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
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
                Icons.chevron_right_rounded,
                size: 18,
                color: t.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
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

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ThemeOption(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: value == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.auto_mode_outlined,
            label: 'System',
            selected: value == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: value == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? t.surfaceCard : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected ? Border.all(color: t.borderSubtle) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? t.accentGold : t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? t.textPrimary : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

