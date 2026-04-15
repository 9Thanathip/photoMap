import 'package:flutter/material.dart';
import 'gold_text.dart';

class AchievementsStatsCard extends StatelessWidget {
  const AchievementsStatsCard({
    super.key,
    required this.visited,
    required this.total,
    required this.progress,
  });

  final int visited;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF141420) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGold2.withValues(alpha: 0.35)),
        boxShadow: context.isDark
            ? null
            : [BoxShadow(color: context.dimB(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: kGold1, size: 16),
            const SizedBox(width: 6),
            GoldText('Thailand Explorer', fontSize: 12, fontWeight: FontWeight.w600),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GoldText('${(progress * 100).toStringAsFixed(0)}%',
                  fontSize: 32, fontWeight: FontWeight.w700),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('$visited / $total',
                    style: TextStyle(fontSize: 12, color: context.dim(0.35, 0.35))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.dim(0.07, 0.08),
              valueColor: const AlwaysStoppedAnimation(kGold1),
            ),
          ),
          const SizedBox(height: 10),
          Text('${total - visited} provinces remaining',
              style: TextStyle(fontSize: 11, color: context.dim(0.3, 0.3))),
        ],
      ),
    );
  }
}
