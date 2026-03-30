import 'dart:math';

/// A simple utility to chain and generate 4x5 color matrices used by Flutter's [ColorFilter.matrix].
class ColorMatrix {
  final List<double> matrix;

  const ColorMatrix(this.matrix);

  static const ColorMatrix identity = ColorMatrix([
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  /// Computes (this * other).
  /// Note: Flutter matrices are 4x5 (omitting the implicit 5th row [0, 0, 0, 0, 1]).
  ColorMatrix multiply(ColorMatrix other) {
    final a = matrix;
    final b = other.matrix;
    final res = List<double>.filled(20, 0.0);

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 5; j++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[i * 5 + k] * b[k * 5 + j];
        }
        if (j == 4) {
          sum += a[i * 5 + 4]; // Add the translation component of `this`
        }
        res[i * 5 + j] = sum;
      }
    }
    return ColorMatrix(res);
  }

  // ── Generators for Manual Adjustments ──────────────────────────────────────

  /// Exposure: v > 0 brightens, v < 0 darkens. Usually -1.0 to 1.0.
  static ColorMatrix exposure(double v) {
    // We adjust brightness linearly via offset to mimic simple exposure slider.
    final offset = v * 255.0;
    return ColorMatrix([
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Contrast: c > 1 increases contrast, 0 < c < 1 decreases it. (e.g., 0.5 to 1.5)
  static ColorMatrix contrast(double c) {
    final t = (1.0 - c) / 2.0 * 255.0;
    return ColorMatrix([
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Saturation: s > 1 increases, 0 < s < 1 decreases. (e.g., 0.0 to 2.0)
  static ColorMatrix saturation(double s) {
    final invS = 1.0 - s;
    final rLum = 0.3086 * invS;
    final gLum = 0.6094 * invS;
    final bLum = 0.0820 * invS;

    return ColorMatrix([
      rLum + s, gLum, bLum, 0, 0,
      rLum, gLum + s, bLum, 0, 0,
      rLum, gLum, bLum + s, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Temperature: t > 0 warms, t < 0 cools. Usually -1.0 to 1.0.
  static ColorMatrix temperature(double t) {
    // Warm: +R, -B. Cool: -R, +B.
    return ColorMatrix([
      1 + max(0.0, t * 0.2), 0, 0, 0, t * 30,
      0, 1, 0, 0, 0,
      0, 0, 1 + max(0.0, -t * 0.2), 0, -t * 30,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Tint: t > 0 adds green, t < 0 adds magenta. Usually -1.0 to 1.0.
  static ColorMatrix tint(double t) {
    return ColorMatrix([
      1, 0, 0, 0, -t * 20,
      0, 1 + max(0.0, t * 0.2), 0, 0, t * 20,
      0, 0, 1, 0, -t * 20,
      0, 0, 0, 1, 0,
    ]);
  }

  // ── Film Presets (VSCO style approx) ───────────────────────────────────────

  static const ColorMatrix f1 = ColorMatrix([ // Fade & Moody Film
    1.1, 0.0, 0.0, 0.0, -10,
    0.0, 1.0, 0.0, 0.0, 0,
    0.0, 0.0, 0.9, 0.0, 15,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix c1 = ColorMatrix([ // Vibrant Candy
    1.2, -0.1, -0.1, 0.0, 10,
    -0.1, 1.2, -0.1, 0.0, 10,
    -0.1, -0.1, 1.2, 0.0, 10,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix m5 = ColorMatrix([ // Warm Vintage
    1.2, 0.1, 0.0, 0.0, 20,
    0.0, 1.0, 0.0, 0.0, 10,
    0.0, 0.0, 0.8, 0.0, -10,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix b1 = ColorMatrix([ // Classic B&W
    0.3, 0.59, 0.11, 0.0, 0,
    0.3, 0.59, 0.11, 0.0, 0,
    0.3, 0.59, 0.11, 0.0, 0,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix p5 = ColorMatrix([ // Cool Polaroid
    0.9, 0.0, 0.0, 0.0, -10,
    0.0, 1.0, 0.0, 0.0, 10,
    0.0, 0.0, 1.2, 0.0, 30,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);
}

class FilterPreset {
  final String id;
  final String name;
  final ColorMatrix matrix;

  const FilterPreset(this.id, this.name, this.matrix);
}

const List<FilterPreset> kFilmPresets = [
  FilterPreset('O', 'Original', ColorMatrix.identity),
  FilterPreset('F1', 'Moody', ColorMatrix.f1),
  FilterPreset('C1', 'Vibrant', ColorMatrix.c1),
  FilterPreset('M5', 'Vintage', ColorMatrix.m5),
  FilterPreset('P5', 'Polaroid', ColorMatrix.p5),
  FilterPreset('B1', 'B&W', ColorMatrix.b1),
];
