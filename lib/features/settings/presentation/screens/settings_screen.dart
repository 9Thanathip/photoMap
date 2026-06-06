import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authNotifierProvider);
    final t = context.tokens;
    final topPad = MediaQuery.paddingOf(context).top;

    final email = auth.email ?? '';
    final name = (auth.displayName?.trim().isNotEmpty ?? false)
        ? auth.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : l10n.defaultUserName);

    return Scaffold(
      backgroundColor: t.surfaceBase,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 120),
        children: [
          // ── Header ──
          Text(
            l10n.settingsTitle,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.settingsSubtitle,
            style: GoogleFonts.inter(fontSize: 14, color: t.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Appearance ──
          _SectionLabel(l10n.sectionAppearance),
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
                          l10n.appTheme,
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
                      lightLabel: l10n.themeLight,
                      systemLabel: l10n.themeSystem,
                      darkLabel: l10n.themeDark,
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
          _SectionLabel(l10n.sectionGeneral),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.language_outlined,
                iconColor: t.accentGold,
                title: l10n.settingsLanguage,
                trailing: Text(
                  _localeLabel(l10n, locale),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: t.textSecondary,
                  ),
                ),
                onTap: () => _showLanguageSheet(context, ref, locale),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Account ──
          _SectionLabel(l10n.sectionAccount),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _ProfileTile(
                name: name,
                email: email,
                onTap: () => context.push('/profile'),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── About ──
          _SectionLabel(l10n.sectionAbout),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: t.textSecondary,
                title: l10n.settingsVersion,
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

  String _localeLabel(AppLocalizations l10n, Locale? locale) {
    switch (locale?.languageCode) {
      case 'en':
        return l10n.languageEnglish;
      case 'th':
        return l10n.languageThai;
      default:
        return l10n.languageSystemDefault;
    }
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref, Locale? current) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final options = <(String, Locale?)>[
          (l10n.languageSystemDefault, null),
          (l10n.languageEnglish, const Locale('en')),
          (l10n.languageThai, const Locale('th')),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  l10n.settingsLanguage,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              for (final (label, value) in options)
                ListTile(
                  title: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
                    ),
                  ),
                  trailing: current?.languageCode == value?.languageCode
                      ? Icon(Icons.check_rounded, color: t.accentGold)
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(value);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
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
                      color: t.textPrimary,
                    ),
                  ),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.email,
    this.onTap,
  });

  final String name;
  final String email;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accentGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.accentGold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: t.textTertiary,
              ),
            ],
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

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.value,
    required this.onChanged,
    required this.lightLabel,
    required this.systemLabel,
    required this.darkLabel,
  });
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  final String lightLabel;
  final String systemLabel;
  final String darkLabel;

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
            label: lightLabel,
            selected: value == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.auto_mode_outlined,
            label: systemLabel,
            selected: value == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_outlined,
            label: darkLabel,
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

