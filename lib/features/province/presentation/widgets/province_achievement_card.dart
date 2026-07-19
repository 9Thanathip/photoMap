import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/core/theme/app_palette.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'gold_text.dart';

class ProvinceAchievementCard extends StatelessWidget {
  const ProvinceAchievementCard({
    super.key,
    required this.name,
    required this.visited,
    required this.photos,
    required this.isExpanded,
    required this.onTap,
    required this.onViewAll,
  });

  final String name;
  final bool visited;
  final List<PhotoItem> photos;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borderColor = visited
        ? t.accentGoldDeep.withValues(alpha: context.isDark ? 0.55 : 0.42)
        : t.borderStrong;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: visited ? LinearGradient(colors: t.goldRowGradient) : null,
          color: visited ? null : (context.isDark ? t.surfaceCard : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: visited && isExpanded
              ? [BoxShadow(
                  color: t.accentGold.withValues(alpha: context.isDark ? 0.08 : 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            _CardRow(
              name: name,
              visited: visited,
              photoCount: photos.length,
              isExpanded: isExpanded,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _CardExpanded(photos: photos, visited: visited, onViewAll: onViewAll)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card header row ────────────────────────────────────────────────────────────

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.name,
    required this.visited,
    required this.photoCount,
    required this.isExpanded,
  });

  final String name;
  final bool visited;
  final int photoCount;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          if (visited)
            Container(
              width: 3,
              height: 52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kGold2, kGold1, kGold3],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          SizedBox(width: visited ? 12 : 16),
          if (visited)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: kGoldGrad,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(AppIcons.star_rounded, size: 14, color: Colors.black),
            )
          else
            Icon(AppIcons.lock_outline_rounded, size: 15, color: context.tokens.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: visited && context.isDark
                ? GoldText(name, fontSize: 13, fontWeight: FontWeight.w600)
                : Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: visited ? FontWeight.w600 : FontWeight.w400,
                      color: visited
                          ? (context.isDark ? null : Palette.goldTextOnLight)
                          : context.dim(0.28, 0.25),
                    ),
                  ),
          ),
          if (visited)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$photoCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.isDark
                      ? context.tokens.accentGold.withValues(alpha: 0.7)
                      : context.tokens.accentGoldDeep,
                ),
              ),
            ),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Icon(
              AppIcons.keyboard_arrow_down_rounded,
              size: 18,
              color: visited
                  ? (context.isDark
                      ? context.tokens.accentGold.withValues(alpha: 0.6)
                      : context.tokens.accentGoldDeep.withValues(alpha: 0.7))
                  : context.tokens.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ── Expanded content ───────────────────────────────────────────────────────────

class _CardExpanded extends StatelessWidget {
  const _CardExpanded({
    required this.photos,
    required this.visited,
    required this.onViewAll,
  });

  final List<PhotoItem> photos;
  final bool visited;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (!visited) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Icon(AppIcons.explore_outlined, size: 14, color: context.dim(0.2, 0.2)),
            const SizedBox(width: 6),
            Text(AppLocalizations.of(context).noPhotosYet,
                style: TextStyle(fontSize: 12, color: context.dim(0.3, 0.25))),
          ],
        ),
      );
    }

    final thumbs = ([...photos]..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
        .take(5)
        .toList();

    return Column(
      children: [
        Divider(height: 1, color: context.tokens.dividerSoft),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    for (final p in thumbs)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p.assetEntity != null
                              ? Image(
                                  image: AssetEntityImageProvider(
                                    p.assetEntity!,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize.square(150),
                                  ),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                )
                              : _Placeholder(),
                        ),
                      ),
                    if (photos.length > 5)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: context.tokens.accentVioletSurface,
                          alignment: Alignment.center,
                          child: Text(
                            '+${photos.length - 5}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.tokens.accentVioletText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context).photoCount(photos.length),
                    style: TextStyle(fontSize: 12, color: context.dim(0.35, 0.35)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onViewAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: kGoldGrad,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context).viewAll,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black)),
                          const SizedBox(width: 4),
                          const Icon(AppIcons.arrow_forward_rounded, size: 13, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        color: context.tokens.surfaceMuted,
      );
}
