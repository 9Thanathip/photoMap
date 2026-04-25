import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/glass_card.dart';
import 'package:photo_map/features/map/presentation/widgets/map_ui_components.dart';

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
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapActionButton(
            icon: Icons.palette_outlined,
            tooltip: 'Background',
            onTap: onShowSettings,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.black.withOpacity(0.08),
          ),
          MapActionButton(
            icon: Icons.center_focus_strong_outlined,
            tooltip: 'Center Map',
            onTap: onResetView,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.black.withOpacity(0.08),
          ),
          MapActionButton(
            icon: isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
            tooltip: 'Save to Photos',
            onTap: onDownload,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.black.withOpacity(0.08),
          ),
          MapActionButton(
            icon: Icons.ios_share,
            tooltip: 'Share',
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}
