import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';

/// Ranks the provinces with the most photos as a compact horizontal-bar
/// list. Bars are relative to the top province so the ranking reads at a
/// glance.
class TopProvincesCard extends StatelessWidget {
  const TopProvincesCard({
    super.key,
    required this.photosByProvince,
    this.maxEntries = 5,
  });

  final Map<String, List<Object>> photosByProvince;
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;

    final ranked = photosByProvince.entries
        .map((e) => (name: e.key, count: e.value.length))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final top = ranked.take(maxEntries).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.count;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: t.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statsTopProvinces,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (final (i, entry) in top.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == 0 ? t.accentGold : t.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.count}',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxCount == 0 ? 0 : entry.count / maxCount,
                          minHeight: 5,
                          backgroundColor:
                              t.textPrimary.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            i == 0 ? t.accentGold : t.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
