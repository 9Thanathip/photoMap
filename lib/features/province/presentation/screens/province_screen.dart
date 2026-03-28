import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/province_data.dart';

final _visitedProvider = StateProvider<Set<String>>((ref) => {'Bangkok', 'Chiang Mai', 'Phuket'});

class ProvinceScreen extends ConsumerWidget {
  const ProvinceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visited = ref.watch(_visitedProvider);
    final theme = Theme.of(context);

    final regions = thaiProvinces.map((p) => p.region).toSet().toList();
    final grouped = {
      for (final r in regions)
        r: thaiProvinces.where((p) => p.region == r).toList(),
    };

    final total = thaiProvinces.length;
    final visitedCount = thaiProvinces.where((p) => visited.contains(p.name)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Province')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressCard(visited: visitedCount, total: total),
                  const Gap(20),
                  _AchievementRow(visited: visitedCount),
                ],
              ),
            ),
          ),
          for (final entry in grouped.entries) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      entry.key,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      '${entry.value.where((p) => visited.contains(p.name)).length}/${entry.value.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: entry.value.length,
              itemBuilder: (context, i) {
                final province = entry.value[i];
                final isVisited = visited.contains(province.name);
                return _ProvinceItem(
                  province: province,
                  isVisited: isVisited,
                  onTap: () {
                    ref.read(_visitedProvider.notifier).update((s) {
                      final next = Set<String>.from(s);
                      isVisited ? next.remove(province.name) : next.add(province.name);
                      return next;
                    });
                  },
                );
              },
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.visited, required this.total});

  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = visited / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
              const Gap(8),
              Text(
                'Thailand Explorer',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visited',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '/ $total provinces',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const Gap(6),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% of Thailand explored',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.visited});

  final int visited;

  static const _badges = [
    _Badge('Beginner', Icons.star_outline, 1),
    _Badge('Explorer', Icons.explore, 10),
    _Badge('Adventurer', Icons.hiking, 25),
    _Badge('Champion', Icons.emoji_events, 50),
    _Badge('Legend', Icons.workspace_premium, 77),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Gap(12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _badges.map((b) {
              final unlocked = visited >= b.threshold;
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        border: unlocked
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        b.icon,
                        color: unlocked
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        size: 26,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      b.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: unlocked ? null : theme.colorScheme.outlineVariant,
                        fontWeight: unlocked ? FontWeight.w600 : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${b.threshold} provs',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProvinceItem extends StatelessWidget {
  const _ProvinceItem({
    required this.province,
    required this.isVisited,
    required this.onTap,
  });

  final Province province;
  final bool isVisited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Text(province.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        province.name,
        style: TextStyle(
          fontWeight: isVisited ? FontWeight.w600 : FontWeight.normal,
          decoration: isVisited ? null : null,
        ),
      ),
      trailing: isVisited
          ? Icon(Icons.check_circle_rounded,
              color: theme.colorScheme.primary, size: 22)
          : Icon(Icons.radio_button_unchecked_rounded,
              color: theme.colorScheme.outlineVariant, size: 22),
      onTap: onTap,
    );
  }
}

class _Badge {
  const _Badge(this.label, this.icon, this.threshold);

  final String label;
  final IconData icon;
  final int threshold;
}
