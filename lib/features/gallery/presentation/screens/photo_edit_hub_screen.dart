import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import '../providers/gallery_notifier.dart';
import '../widgets/collage/collage_builder_screen.dart';
import '../widgets/editor/photo_editor_screen.dart';
import '../widgets/frame/frame_export_screen.dart';
import '../widgets/frame/frame_style.dart';
import '../widgets/photo_picker_sheet.dart';

/// Landing page for everything that edits a single photo.
///
/// Feature first, photo second: the editors are otherwise only reachable from
/// inside the viewer, which means knowing to open a photo before you can find
/// out what can be done to one.
class PhotoEditHubScreen extends ConsumerWidget {
  const PhotoEditHubScreen({super.key});

  /// Asks which photo, then hands it to [open]. Nothing happens if the picker
  /// is dismissed.
  Future<void> _pickThen(
    BuildContext context,
    WidgetRef ref,
    Widget Function(PhotoItem photo) open,
  ) async {
    final photo = await pickOnePhoto(
      context,
      photos: ref.read(galleryStateProvider).allPhotos,
      // Every destination here paints a still; a video would arrive as a frozen
      // first frame with no way back to the video.
      imagesOnly: true,
    );
    if (photo == null || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => open(photo)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.surfaceBase,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, l10n, t),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Text(
                  l10n.editHubHint,
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              ),
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    _EditOption(
                      icon: AppIcons.tune_rounded,
                      title: l10n.editHubAdjust,
                      subtitle: l10n.editHubAdjustDesc,
                      onTap: () => _pickThen(
                        context,
                        ref,
                        (photo) => PhotoEditorScreen(
                          photo: photo,
                          // Deliberately not photo.path: that tag belongs to the
                          // grid tile two routes down, and matching it would fly
                          // the Hero from a tile the user cannot see.
                          heroTag: 'edit_hub_${photo.path}',
                        ),
                      ),
                    ),
                    _EditOption(
                      icon: AppIcons.dashboard_customize_outlined,
                      title: l10n.editHubCollage,
                      subtitle: l10n.editHubCollageDesc,
                      // The only one that takes several photos, so it picks
                      // them itself, cell by cell.
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CollageBuilderScreen(),
                        ),
                      ),
                    ),
                    _EditOption(
                      icon: AppIcons.camera_alt_rounded,
                      title: l10n.editHubExif,
                      subtitle: l10n.editHubExifDesc,
                      onTap: () => _pickThen(
                        context,
                        ref,
                        // The frame editor, opened on the layout that prints
                        // the shooting data. Its other border styles are a tap
                        // away once inside, so they need no entry of their own.
                        (photo) => FrameExportScreen(
                          photo: photo,
                          initialStyle: FrameStyle.bottomBar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
      BuildContext context, AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: t.textSecondary),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            l10n.editHubTitle,
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          // Balances the cancel button so the title stays centred.
          const SizedBox(width: 64),
        ],
      ),
    );
  }
}

class _EditOption extends StatelessWidget {
  const _EditOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: t.textPrimary),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
