import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';

/// Explorer progress card: a white glass panel with a subtle gold tint,
/// showing the country, an arc progress ring and the visited / remaining
/// counts. Modeled on the achievements hero card.
class ProvinceProgressCard extends StatelessWidget {
  const ProvinceProgressCard({
    super.key,
    required this.country,
    required this.visited,
    required this.total,
  });

  final String country;
  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final progress = total == 0 ? 0.0 : visited / total;
    final pct = (progress * 100).round();
    final left = (total - visited).clamp(0, total);
    final gold = t.accentGold;

    // Warm gold → cool periwinkle: a soft two-tone wash behind the glass.
    const blobWarm = Color(0xFFF2C24C);
    const blobCool = Color(0xFF6E93F7);
    final glassFill = context.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gold.withValues(alpha: 0.30), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Two soft colour blobs behind the glass — minimal, frosted.
          Positioned(
            top: -46,
            left: -30,
            child: _Blob(color: blobWarm, size: 170),
          ),
          Positioned(
            bottom: -50,
            right: -24,
            child: _Blob(color: blobCool, size: 150),
          ),
          // Frosted glass layer over the blobs.
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: ColoredBox(color: glassFill),
            ),
          ),
          // Content on top.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.achExplorerLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: t.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        country,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.achExplorerSubtitle,
                        style: TextStyle(fontSize: 13, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Jaruek',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: t.textPrimary.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: progress,
                      track: t.textTertiary.withValues(alpha: 0.22),
                      fill: t.goldGrad,
                      stroke: 11,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.achExplored,
                            style:
                                TextStyle(fontSize: 11, color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stat(
                        value: '$visited',
                        suffix: ' /$total',
                        label: l10n.achProvincesVisited,
                        t: t,
                      ),
                      Divider(height: 22, color: t.borderSubtle),
                      _Stat(
                        value: '$left',
                        label: l10n.achLeftToExplore,
                        t: t,
                      ),
                    ],
                  ),
                ),
              ],
            ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.55),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.t,
    this.suffix,
  });

  final String value;
  final String? suffix;
  final String label;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: t.textPrimary,
            ),
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 13, color: t.textSecondary)),
      ],
    );
  }
}

/// Draws a 270° rounded progress arc (gap at the bottom).
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.stroke,
  });

  final double progress;
  final Color track;
  final List<Color> fill;
  final double stroke;

  static const _start = math.pi * 0.75; // 135° (down-left)
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        _start,
        _sweep * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: _start,
            endAngle: _start + _sweep,
            colors: fill,
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}
