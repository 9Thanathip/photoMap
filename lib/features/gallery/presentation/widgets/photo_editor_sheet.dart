import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_notifier.dart';

class PhotoEditorSheet extends ConsumerStatefulWidget {
  const PhotoEditorSheet({
    super.key,
    required this.photo,
    required this.heroTag,
  });

  final PhotoItem photo;
  final String heroTag;

  @override
  ConsumerState<PhotoEditorSheet> createState() => _PhotoEditorSheetState();
}

class _PhotoEditorSheetState extends ConsumerState<PhotoEditorSheet> {
  int _selectedFilter = 0;

  static const _filters = [
    _Filter('Original', Colors.transparent),
    _Filter('Warm', Color(0xFFFF6B35)),
    _Filter('Cool', Color(0xFF4FC3F7)),
    _Filter('B&W', Colors.grey),
    _Filter('Vivid', Color(0xFFAB47BC)),
    _Filter('Fade', Color(0xFFB0BEC5)),
    _Filter('Drama', Color(0xFF37474F)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                Text('Edit Photo',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done')),
              ],
            ),
            Expanded(
              child: Hero(
                tag: widget.heroTag,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _selectedFilter == 0
                        ? Colors.transparent
                        : _filters[_selectedFilter].color.withAlpha(60),
                    BlendMode.overlay,
                  ),
                  child: widget.photo.assetEntity != null
                      ? Image(
                          image: AssetEntityImageProvider(
                              widget.photo.assetEntity!,
                              isOriginal: true),
                          fit: BoxFit.contain,
                        )
                      : const SizedBox(),
                ),
              ),
            ),
            const Gap(12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final isSelected = _selectedFilter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2.5)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  i == 0
                                      ? Colors.transparent
                                      : _filters[i].color.withAlpha(80),
                                  BlendMode.overlay,
                                ),
                                child: widget.photo.assetEntity != null
                                    ? Image(
                                        image: AssetEntityImageProvider(
                                          widget.photo.assetEntity!,
                                          isOriginal: false,
                                          thumbnailSize:
                                              const ThumbnailSize.square(100),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox(),
                              ),
                            ),
                          ),
                          const Gap(4),
                          Text(
                            _filters[i].name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  isSelected ? theme.colorScheme.primary : null,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Gap(MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _Filter {
  const _Filter(this.name, this.color);

  final String name;
  final Color color;
}
