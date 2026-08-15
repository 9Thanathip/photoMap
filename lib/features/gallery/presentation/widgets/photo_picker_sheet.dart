import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/common_widgets/glass_sheet.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import '../providers/gallery_notifier.dart';

/// Opens [PhotoPickerSheet] for a single photo and returns what was picked.
Future<PhotoItem?> pickOnePhoto(
  BuildContext context, {
  required List<PhotoItem> photos,
  bool imagesOnly = false,
}) async {
  final picked = await showModalBottomSheet<List<PhotoItem>>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PhotoPickerSheet(photos: photos, imagesOnly: imagesOnly),
  );
  return (picked == null || picked.isEmpty) ? null : picked.first;
}

/// Bottom-sheet grid for picking photos. In [multi] mode the user taps to
/// toggle several (numbered by pick order) then confirms; otherwise the first
/// tap returns immediately. Always pops a `List<PhotoItem>`.
class PhotoPickerSheet extends StatefulWidget {
  const PhotoPickerSheet({
    super.key,
    required this.photos,
    this.multi = false,
    this.capacity = 1,
    this.progress,
    this.imagesOnly = false,
  });

  final List<PhotoItem> photos;
  final bool multi;

  /// Max photos selectable in [multi] mode.
  final int capacity;

  /// Line under the count telling the user what they are filling, e.g.
  /// `Grid 3/9 filled`. Built by the caller so this sheet stays free of any
  /// one screen's wording.
  final String? progress;

  /// Drops videos. For destinations that can only take a still.
  final bool imagesOnly;

  @override
  State<PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<PhotoPickerSheet> {
  final List<PhotoItem> _selected = [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final images = widget.photos
        .where((p) =>
            p.assetEntity != null &&
            (!widget.imagesOnly || p.assetEntity!.type == AssetType.image))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => GlassSheet(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  // Always reachable: a sheet this tall leaves the swipe-down
                  // and the scrim above it a long way from the thumb.
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: t.textSecondary,
                    ),
                    child: Text(
                      l10n.commonCancel,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const Spacer(),
                  if (widget.multi) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selected.length} / ${widget.capacity}',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.progress != null)
                          Text(
                            widget.progress!,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.textPrimary,
                        foregroundColor: t.surfaceBase,
                      ),
                      child: Text(l10n.commonDone),
                    ),
                  ] else
                    Text(
                      l10n.photoPickerTitle,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              // Interactive so the thumb can be dragged: a whole library is
              // thousands of rows, and flicking through it is the slow way.
              child: Scrollbar(
                controller: controller,
                interactive: true,
                thumbVisibility: true,
                child: GridView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: images.length,
                itemBuilder: (context, i) {
                  final p = images[i];
                  final order = _selected.indexOf(p);
                  return GestureDetector(
                    onTap: () {
                      if (!widget.multi) {
                        Navigator.pop(context, [p]);
                        return;
                      }
                      if (order < 0 && _selected.length >= widget.capacity) {
                        HapticFeedback.lightImpact();
                        return; // grid full — no more slots
                      }
                      setState(() {
                        order >= 0 ? _selected.remove(p) : _selected.add(p);
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AssetThumb(asset: p.assetEntity!, maxPixels: 800),
                        if (widget.multi && order >= 0) ...[
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4C9AFF),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${order + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
