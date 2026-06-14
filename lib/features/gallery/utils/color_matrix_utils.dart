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

  /// Faded shadows: lifts the black point and gently lowers contrast for the
  /// milky, washed-out look of aged film. v in 0.0 (none) .. 1.0 (strong).
  static ColorMatrix fade(double v) {
    final lift = v * 42.0; // raise blacks toward grey
    final gain = 1.0 - v * 0.14; // soften overall contrast a touch
    return ColorMatrix([
      gain, 0, 0, 0, lift,
      0, gain, 0, 0, lift,
      0, 0, gain, 0, lift,
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

  // ── Film emulation presets ─────────────────────────────────────────────────
  // Hand-tuned 4x5 matrices approximating classic film stocks. Each balances a
  // colour cast (warm/cool/green), saturation, and black-point lift to evoke
  // the look without going garish. Matrix layout per row:
  //   rR rG rB 0 rOff / gR gG gB 0 gOff / bR bG bB 0 bOff / 0 0 0 1 0

  static const ColorMatrix portra400 = ColorMatrix([ // warm, soft skin
    1.08, 0.02, 0.00, 0.0, 6,
    0.02, 1.02, 0.00, 0.0, 4,
    0.00, 0.02, 0.96, 0.0, 2,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix gold200 = ColorMatrix([ // golden, yellow warmth
    1.12, 0.04, 0.00, 0.0, 10,
    0.00, 1.04, 0.02, 0.0, 6,
    0.00, 0.00, 0.86, 0.0, -4,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix ektar100 = ColorMatrix([ // vivid, clean saturation
    1.22, -0.12, -0.06, 0.0, 2,
    -0.08, 1.20, -0.08, 0.0, 2,
    -0.06, -0.12, 1.24, 0.0, 0,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix pro400h = ColorMatrix([ // pastel, airy, cyan-green
    0.98, 0.04, 0.00, 0.0, 8,
    0.00, 1.02, 0.04, 0.0, 8,
    0.02, 0.06, 1.00, 0.0, 6,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix superia = ColorMatrix([ // punchy green
    1.06, -0.04, 0.00, 0.0, 2,
    -0.02, 1.12, -0.04, 0.0, 4,
    0.00, -0.02, 1.04, 0.0, 2,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix cinestill = ColorMatrix([ // tungsten cool, cinematic
    1.00, 0.00, 0.06, 0.0, -6,
    0.00, 1.00, 0.04, 0.0, -2,
    0.04, 0.02, 1.16, 0.0, 14,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix agfaVista = ColorMatrix([ // warm red-yellow
    1.18, 0.00, -0.04, 0.0, 6,
    0.00, 1.06, -0.02, 0.0, 2,
    0.00, 0.00, 0.92, 0.0, -2,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix ilfordHp5 = ColorMatrix([ // B&W classic, mid tone
    0.33, 0.50, 0.17, 0.0, 4,
    0.33, 0.50, 0.17, 0.0, 4,
    0.33, 0.50, 0.17, 0.0, 4,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix triX = ColorMatrix([ // B&W contrasty, deep blacks
    0.36, 0.708, 0.132, 0.0, -24,
    0.36, 0.708, 0.132, 0.0, -24,
    0.36, 0.708, 0.132, 0.0, -24,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix polaroid600 = ColorMatrix([ // faded, milky, cool
    0.90, 0.00, 0.00, 0.0, 12,
    0.00, 0.94, 0.00, 0.0, 16,
    0.00, 0.00, 0.98, 0.0, 18,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix lomo = ColorMatrix([ // saturated, moody edges
    1.20, -0.08, -0.06, 0.0, -4,
    -0.06, 1.18, -0.08, 0.0, -2,
    -0.04, -0.06, 1.14, 0.0, -2,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix velvia = ColorMatrix([ // ultra-saturated landscape
    1.32, -0.18, -0.10, 0.0, -6,
    -0.12, 1.30, -0.14, 0.0, -4,
    -0.08, -0.16, 1.34, 0.0, -4,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix portra800 = ColorMatrix([ // warm low-light
    1.10, 0.02, 0.00, 0.0, 4,
    0.00, 1.00, 0.00, 0.0, 2,
    0.02, 0.00, 0.94, 0.0, 0,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix expired = ColorMatrix([ // green-yellow decay, faded
    1.04, 0.06, 0.00, 0.0, 10,
    0.00, 1.06, 0.04, 0.0, 12,
    0.04, 0.04, 0.84, 0.0, 6,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix crossProcess = ColorMatrix([ // punchy colour twist
    1.16, 0.00, -0.08, 0.0, -4,
    -0.04, 1.14, -0.06, 0.0, 2,
    0.06, 0.00, 1.06, 0.0, 8,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix sepia = ColorMatrix([ // warm brown monochrome
    0.393, 0.769, 0.189, 0.0, 0,
    0.349, 0.686, 0.168, 0.0, 0,
    0.272, 0.534, 0.131, 0.0, 0,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix fadedRetro = ColorMatrix([ // muted, lifted blacks
    0.86, 0.04, 0.04, 0.0, 18,
    0.04, 0.86, 0.04, 0.0, 18,
    0.04, 0.04, 0.86, 0.0, 18,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix tealOrange = ColorMatrix([ // cinematic warm/teal
    1.16, 0.00, -0.06, 0.0, 4,
    0.00, 1.02, 0.00, 0.0, 0,
    -0.04, 0.00, 1.12, 0.0, 6,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix vintageCool = ColorMatrix([ // blue shadows, faded
    0.96, 0.00, 0.04, 0.0, 6,
    0.00, 0.98, 0.04, 0.0, 8,
    0.06, 0.02, 1.02, 0.0, 14,
    0.0, 0.0, 0.0, 1.0, 0,
  ]);

  static const ColorMatrix goldenHour = ColorMatrix([ // strong warm glow
    1.20, 0.06, 0.00, 0.0, 14,
    0.02, 1.04, 0.00, 0.0, 6,
    0.00, 0.00, 0.80, 0.0, -6,
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

  // Film emulation stocks. `id` is the short badge shown above each thumbnail;
  // `name` is the full label (kept in English — these are stock proper nouns).
  FilterPreset('PT4', 'Portra 400', ColorMatrix.portra400),
  FilterPreset('GD2', 'Gold 200', ColorMatrix.gold200),
  FilterPreset('EK1', 'Ektar 100', ColorMatrix.ektar100),
  FilterPreset('PR4', 'Pro 400H', ColorMatrix.pro400h),
  FilterPreset('SUP', 'Superia', ColorMatrix.superia),
  FilterPreset('C8T', 'CineStill', ColorMatrix.cinestill),
  FilterPreset('AGF', 'Agfa Vista', ColorMatrix.agfaVista),
  FilterPreset('HP5', 'Ilford HP5', ColorMatrix.ilfordHp5),
  FilterPreset('TRX', 'Tri-X', ColorMatrix.triX),
  FilterPreset('P60', 'Polaroid 600', ColorMatrix.polaroid600),
  FilterPreset('LOM', 'Lomo', ColorMatrix.lomo),
  FilterPreset('VLV', 'Velvia', ColorMatrix.velvia),
  FilterPreset('PT8', 'Portra 800', ColorMatrix.portra800),
  FilterPreset('EXP', 'Expired', ColorMatrix.expired),
  FilterPreset('XPR', 'X-Process', ColorMatrix.crossProcess),
  FilterPreset('SEP', 'Sepia', ColorMatrix.sepia),
  FilterPreset('FAD', 'Faded', ColorMatrix.fadedRetro),
  FilterPreset('TLO', 'Teal & Orange', ColorMatrix.tealOrange),
  FilterPreset('VTC', 'Vintage Cool', ColorMatrix.vintageCool),
  FilterPreset('GLD', 'Golden Hour', ColorMatrix.goldenHour),
];
