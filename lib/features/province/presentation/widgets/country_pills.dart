import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'achievements_stats.dart';
import 'gold_text.dart';

class CountryPills extends StatelessWidget {
  const CountryPills({
    super.key,
    required this.countries,
    required this.selected,
    required this.stats,
    required this.onSelected,
  });

  final Set<String> countries;
  final String selected;
  final AchievementsStats stats;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = countries.toList()..sort();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = sorted[i];
          final sel = c == selected;
          final count = stats.countriesVisited[c]?.length ?? 0;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: sel ? kGoldGrad : null,
                color: sel
                    ? null
                    : (context.isDark ? const Color(0xFF1C1C28) : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                c != 'Thailand' && count > 0 ? '$c · $count' : c,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? Colors.black : context.dim(0.55, 0.55),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
