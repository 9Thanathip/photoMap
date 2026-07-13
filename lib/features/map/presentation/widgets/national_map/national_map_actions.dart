import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/features/map/presentation/widgets/map_ui_components.dart';
import 'package:photo_map/l10n/app_localizations.dart';

class NationalMapActions extends StatelessWidget {
  const NationalMapActions({
    super.key,
    required this.isDownloading,
    required this.onShowSettings,
    required this.onResetView,
    required this.onDownload,
    required this.onShare,
  });

  final bool isDownloading;
  final VoidCallback onShowSettings;
  final VoidCallback onResetView;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapActionButton(
            icon: Icons.palette_outlined,
            tooltip: l10n.tooltipBackground,
            onTap: onShowSettings,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
          ),
          MapActionButton(
            icon: Icons.center_focus_strong_outlined,
            tooltip: l10n.tooltipCenterMap,
            onTap: onResetView,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
          ),
          MapActionButton(
            icon: isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
            tooltip: l10n.tooltipSaveToPhotos,
            onTap: onDownload,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: dividerColor,
          ),
          MapActionButton(
            icon: Icons.ios_share,
            tooltip: l10n.tooltipShare,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}
