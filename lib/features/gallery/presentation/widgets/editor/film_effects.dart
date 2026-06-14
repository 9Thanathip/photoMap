import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Film-style overlay effects that sit *on top* of the colour-graded image:
/// grain, vignette and a warm light leak. All three are painted by the same
/// [paintFilmOverlays] routine so the live editor preview and the baked export
/// look identical.
///
/// Intensities are 0.0 (off) .. 1.0 (strong). The grain pattern is a fixed,
/// seed-deterministic set of normalized points scaled into the target rect, so
/// a low-res preview and a full-res save share the exact same grain.

class _GrainPattern {
  _GrainPattern._();

  // Normalized [0,1) point coordinates, split into "light" specks (added) and
  // "dark" specks (subtracted) to mimic luminance noise.
  static Float32List? _lightNorm;
  static Float32List? _darkNorm;

  static const int _count = 9000;
  static const int _seed = 20240611;

  static void _ensure() {
    if (_lightNorm != null) return;
    final rnd = Random(_seed);
    final light = <double>[];
    final dark = <double>[];
    for (var i = 0; i < _count; i++) {
      final x = rnd.nextDouble();
      final y = rnd.nextDouble();
      if (rnd.nextBool()) {
        light..add(x)..add(y);
      } else {
        dark..add(x)..add(y);
      }
    }
    _lightNorm = Float32List.fromList(light);
    _darkNorm = Float32List.fromList(dark);
  }

  /// Maps the normalized pattern into absolute coordinates for [rect].
  static (Float32List light, Float32List dark) scaledTo(Rect rect) {
    _ensure();
    Float32List map(Float32List src) {
      final out = Float32List(src.length);
      for (var i = 0; i < src.length; i += 2) {
        out[i] = rect.left + src[i] * rect.width;
        out[i + 1] = rect.top + src[i + 1] * rect.height;
      }
      return out;
    }

    return (map(_lightNorm!), map(_darkNorm!));
  }
}

void _paintVignette(Canvas canvas, Rect rect, double intensity) {
  final shader = RadialGradient(
    center: Alignment.center,
    radius: 0.85,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.0),
      Colors.black.withValues(alpha: (intensity * 0.75).clamp(0.0, 1.0)),
    ],
    stops: const [0.0, 0.5, 1.0],
  ).createShader(rect);
  canvas.drawRect(rect, Paint()..shader = shader);
}

void _paintLightLeak(
  Canvas canvas,
  Rect rect,
  double intensity,
  Alignment direction,
) {
  final shader = LinearGradient(
    begin: direction,
    end: -direction, // opposite corner/edge
    colors: [
      const Color(0xFFFFB14E).withValues(alpha: (intensity * 0.55).clamp(0.0, 1.0)),
      const Color(0xFFFF5E3A).withValues(alpha: (intensity * 0.24).clamp(0.0, 1.0)),
      Colors.transparent,
    ],
    stops: const [0.0, 0.28, 0.62],
  ).createShader(rect);
  // Additive blend so it reads as light spilling onto the frame.
  canvas.drawRect(rect, Paint()..shader = shader..blendMode = BlendMode.plus);
}

void _paintGrain(Canvas canvas, Rect rect, double intensity) {
  final (light, dark) = _GrainPattern.scaledTo(rect);
  final dot = (rect.shortestSide * 0.0026).clamp(0.6, 6.0);

  final lightPaint = Paint()
    ..color = Colors.white.withValues(alpha: (intensity * 0.18).clamp(0.0, 1.0))
    ..strokeWidth = dot
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final darkPaint = Paint()
    ..color = Colors.black.withValues(alpha: (intensity * 0.20).clamp(0.0, 1.0))
    ..strokeWidth = dot
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.multiply;

  canvas.drawRawPoints(PointMode.points, light, lightPaint);
  canvas.drawRawPoints(PointMode.points, dark, darkPaint);
}

/// Paints all enabled film overlays over [rect] in a stable order:
/// light leak (under), vignette (darken edges), then grain (top).
void paintFilmOverlays(
  Canvas canvas,
  Rect rect, {
  double vignette = 0.0,
  double lightLeak = 0.0,
  double grain = 0.0,
  Alignment lightLeakDirection = Alignment.topRight,
}) {
  if (lightLeak > 0) {
    _paintLightLeak(canvas, rect, lightLeak, lightLeakDirection);
  }
  if (vignette > 0) _paintVignette(canvas, rect, vignette);
  if (grain > 0) _paintGrain(canvas, rect, grain);
}

/// Foreground painter for the live editor preview. Use as
/// `CustomPaint(foregroundPainter: FilmOverlayPainter(...), child: image)` so
/// it paints over exactly the image's rendered rect.
class FilmOverlayPainter extends CustomPainter {
  const FilmOverlayPainter({
    required this.vignette,
    required this.lightLeak,
    required this.grain,
    this.lightLeakDirection = Alignment.topRight,
  });

  final double vignette;
  final double lightLeak;
  final double grain;
  final Alignment lightLeakDirection;

  @override
  void paint(Canvas canvas, Size size) {
    paintFilmOverlays(
      canvas,
      Offset.zero & size,
      vignette: vignette,
      lightLeak: lightLeak,
      grain: grain,
      lightLeakDirection: lightLeakDirection,
    );
  }

  @override
  bool shouldRepaint(FilmOverlayPainter old) =>
      old.vignette != vignette ||
      old.lightLeak != lightLeak ||
      old.grain != grain ||
      old.lightLeakDirection != lightLeakDirection;
}
