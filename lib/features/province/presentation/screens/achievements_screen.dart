import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

// ── District counts ────────────────────────────────────────────────────────────

const Map<String, int> _kDistrictCount = {
  'Amnat Charoen': 7,
  'Ang Thong': 7,
  'Bangkok': 50,
  'Bueng Kan': 8,
  'Buriram': 23,
  'Chachoengsao': 11,
  'Chainat': 8,
  'Chaiyaphum': 16,
  'Chanthaburi': 10,
  'Chiang Mai': 25,
  'Chiang Rai': 18,
  'Chonburi': 11,
  'Chumphon': 8,
  'Kalasin': 18,
  'Kamphaeng Phet': 11,
  'Kanchanaburi': 13,
  'Khon Kaen': 26,
  'Krabi': 8,
  'Lampang': 13,
  'Lamphun': 8,
  'Loei': 14,
  'Lopburi': 11,
  'Mae Hong Son': 7,
  'Maha Sarakham': 13,
  'Mukdahan': 7,
  'Nakhon Nayok': 4,
  'Nakhon Pathom': 7,
  'Nakhon Phanom': 12,
  'Nakhon Ratchasima': 32,
  'Nakhon Sawan': 15,
  'Nakhon Si Thammarat': 23,
  'Nan': 15,
  'Narathiwat': 13,
  'Nong Bua Lamphu': 6,
  'Nong Khai': 9,
  'Nonthaburi': 6,
  'Pathum Thani': 7,
  'Pattani': 12,
  'Phang Nga': 8,
  'Phatthalung': 11,
  'Phayao': 9,
  'Phetchabun': 11,
  'Phetchaburi': 8,
  'Phichit': 12,
  'Phitsanulok': 9,
  'Phra Nakhon Si Ayutthaya': 16,
  'Phrae': 8,
  'Phuket': 3,
  'Prachin Buri': 7,
  'Prachuap Khiri Khan': 8,
  'Ranong': 5,
  'Ratchaburi': 10,
  'Rayong': 8,
  'Roi Et': 20,
  'Sa Kaeo': 9,
  'Sakon Nakhon': 18,
  'Samut Prakan': 6,
  'Samut Sakhon': 3,
  'Samut Songkhram': 3,
  'Saraburi': 13,
  'Satun': 7,
  'Sing Buri': 6,
  'Sisaket': 22,
  'Songkhla': 16,
  'Sukhothai': 9,
  'Suphan Buri': 10,
  'Surat Thani': 19,
  'Surin': 17,
  'Tak': 9,
  'Trang': 10,
  'Trat': 7,
  'Ubon Ratchathani': 25,
  'Udon Thani': 20,
  'Uthai Thani': 8,
  'Uttaradit': 9,
  'Yala': 8,
  'Yasothon': 9,
};

// ── Gold palette (same in light & dark) ───────────────────────────────────────
const _kGold1 = Color(0xFFFFD060);
const _kGold2 = Color(0xFFB8860B);
const _kGold3 = Color(0xFFFFF0A0);

// ── Screen ─────────────────────────────────────────────────────────────────────

class ProvinceScreen extends ConsumerWidget {
  const ProvinceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(galleryStateProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visitedSet = <String>{};
    for (final p in gallery.allPhotos) {
      if (p.province.isNotEmpty) visitedSet.add(p.province);
    }

    final allProvinces = _kDistrictCount.keys.toList()..sort();
    final visited = allProvinces.where((p) => visitedSet.contains(p)).toList();
    final unvisited = allProvinces.where((p) => !visitedSet.contains(p)).toList();
    final total = allProvinces.length;
    final progress = total == 0 ? 0.0 : visited.length / total;

    // Build list items: visited section + unvisited section
    // Each item is either a _SectionHeader or a province name (String)
    // We'll pass a sealed-ish approach via a tagged list
    final items = <_ListItem>[
      if (visited.isNotEmpty) ...[
        _SectionItem('Visited · ${visited.length}', true),
        for (final name in visited) _ProvinceItem(name, true),
      ],
      if (unvisited.isNotEmpty) ...[
        _SectionItem('Not Yet · ${unvisited.length}', false),
        for (final name in unvisited) _ProvinceItem(name, false),
      ],
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroHeader(
              topPad: topPad,
              visitedCount: visited.length,
              total: total,
              progress: progress,
              isDark: isDark,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                if (item is _SectionItem) {
                  return _SectionHeader(
                    label: item.label,
                    isVisited: item.isVisited,
                    isDark: isDark,
                  );
                }
                final p = item as _ProvinceItem;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProvinceCard(name: p.name, visited: p.visited, isDark: isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tagged list items ──────────────────────────────────────────────────────────

sealed class _ListItem {}

final class _SectionItem extends _ListItem {
  _SectionItem(this.label, this.isVisited);
  final String label;
  final bool isVisited;
}

final class _ProvinceItem extends _ListItem {
  _ProvinceItem(this.name, this.visited);
  final String name;
  final bool visited;
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.isVisited,
    required this.isDark,
  });

  final String label;
  final bool isVisited;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(
        children: [
          if (isVisited)
            const Icon(Icons.star_rounded, size: 14, color: _kGold1)
          else
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: isVisited
                  ? _kGold2
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Header ────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.topPad,
    required this.visitedCount,
    required this.total,
    required this.progress,
    required this.isDark,
  });

  final double topPad;
  final int visitedCount;
  final int total;
  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: titleColor,
              height: 1.1,
            ),
          ),
          Text(
            'Thailand Explorer',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 28),
          _RingProgress(progress: progress, visited: visitedCount, total: total, isDark: isDark),
          const SizedBox(height: 28),
          _StatsRow(visitedCount: visitedCount, total: total, isDark: isDark),
        ],
      ),
    );
  }
}

// ── Ring Progress ──────────────────────────────────────────────────────────────

class _RingProgress extends StatelessWidget {
  const _RingProgress({
    required this.progress,
    required this.visited,
    required this.total,
    required this.isDark,
  });

  final double progress;
  final int visited;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final centerNumColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final centerSubColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isDark)
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kGold1.withValues(alpha: 0.12),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            CustomPaint(
              size: const Size(180, 180),
              painter: _RingPainter(progress: progress, isDark: isDark),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$visited',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: centerNumColor,
                    height: 1,
                  ),
                ),
                Text(
                  'of $total',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: centerSubColor,
                  ),
                ),
                const SizedBox(height: 4),
                _GoldText(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi,
      colors: const [_kGold2, _kGold1, _kGold3, _kGold1, _kGold2],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    canvas.drawArc(
      rect,
      startAngle,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

// ── Stats Row ──────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.visitedCount,
    required this.total,
    required this.isDark,
  });

  final int visitedCount;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final remaining = total - visitedCount;
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.star_rounded,
            label: 'Visited',
            value: '$visitedCount',
            muted: false,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: Icons.lock_outline_rounded,
            label: 'Remaining',
            value: '$remaining',
            muted: true,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: Icons.public_rounded,
            label: 'Total',
            value: '$total',
            muted: true,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF141420) : Colors.white;
    final borderColor = muted
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.06))
        : _kGold2.withValues(alpha: 0.4);
    final iconColor = muted
        ? (isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.2))
        : _kGold1;
    final valueColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: muted
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.45))
                  : valueColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Province Card ──────────────────────────────────────────────────────────────

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({
    required this.name,
    required this.visited,
    required this.isDark,
  });

  final String name;
  final bool visited;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (visited) {
      final bgGrad = isDark
          ? const LinearGradient(
              colors: [Color(0xFF2A1F00), Color(0xFF3D2E00), Color(0xFF2A1F00)],
              stops: [0.0, 0.5, 1.0],
            )
          : const LinearGradient(
              colors: [Color(0xFFFFF8E0), Color(0xFFFFF3C0), Color(0xFFFFF8E0)],
              stops: [0.0, 0.5, 1.0],
            );
      final textColor = isDark ? null : const Color(0xFF5A3A00);

      return Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: bgGrad,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _kGold2.withValues(alpha: isDark ? 0.6 : 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _kGold1.withValues(alpha: isDark ? 0.06 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kGold2, _kGold1, _kGold3],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Star badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kGold2, _kGold1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star_rounded, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: textColor != null
                  ? Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    )
                  : _GoldText(name, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGold2.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _kGold2.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'VISITED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _kGold2,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Locked
    final surfaceColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE5E5EA);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.15);
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.3);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 17),
          Icon(Icons.lock_outline_rounded, size: 16, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gold gradient text ─────────────────────────────────────────────────────────

class _GoldText extends StatelessWidget {
  const _GoldText(
    this.text, {
    required this.fontSize,
    required this.fontWeight,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_kGold2, _kGold1, _kGold3, _kGold1],
        stops: [0.0, 0.4, 0.6, 1.0],
      ).createShader(bounds),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
      ),
    );
  }
}
