import 'package:flutter/material.dart';

/// Raw color primitives. Do not use directly in features —
/// reference via [AppTokens] (semantic) instead. Kept const so they
/// can be used in `const` widget trees where needed.
abstract final class Palette {
  // Brand
  static const indigo900 = Color(0xFF2D3250);
  static const coral500 = Color(0xFFE94560);
  static const violet500 = Color(0xFF6C63FF);
  static const violet700 = Color(0xFF5A50A0);
  static const violetTintLight = Color(0xFFEEEAFF);
  static const violetTintDark = Color(0xFF2A2040);

  // Gold
  static const gold300 = Color(0xFFFFF0A0);
  static const gold400 = Color(0xFFFFD060);
  static const gold700 = Color(0xFFB8860B);
  static const goldBgDark1 = Color(0xFF251C00);
  static const goldBgDark2 = Color(0xFF3A2A00);
  static const goldBgLight1 = Color(0xFFFFFAEC);
  static const goldBgLight2 = Color(0xFFFFF3C0);
  static const goldTextOnLight = Color(0xFF5A3A00);

  // Neutral — dark
  static const neutral950 = Color(0xFF0A0A0A);
  static const neutral900 = Color(0xFF111111);
  static const neutral880 = Color(0xFF141420);
  static const neutral860 = Color(0xFF161616);
  static const neutral840 = Color(0xFF1A1A26);
  static const neutral820 = Color(0xFF1C1C28);
  static const neutral800 = Color(0xFF1C1C1E);
  static const neutral780 = Color(0xFF1E1E1E);
  static const neutral720 = Color(0xFF2A2A3A);
  static const neutral700 = Color(0xFF2C2C2E);

  // Neutral — light
  static const neutral50 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5EA);
  static const neutral500 = Color(0xFF777777);
  static const neutral400 = Color(0xFFBBBBBB);

  // Map presets (canvas / province / cover crop swatches)
  static const mapStone = Color(0xFFD9D9D9);
  static const mapLight = Color(0xFFE0E0E0);
  static const mapSilver = Color(0xFFAAAAAA);
  static const mapWarm = Color(0xFFD4B896);
  static const mapBlack = Color(0xFF1A1A1A);
  static const mapDark = Color(0xFF444444);
  static const mapWarmSand = Color(0xFFE8D5B7);
  static const mapSage = Color(0xFFB2C9AD);
  static const mapSky = Color(0xFFB8D4E8);
  static const mapSlate = Color(0xFF7A8BA0);
  static const mapCharcoal = Color(0xFF3A3A3A);
  static const mapInk = Color(0xFF1A1A2E);
  static const mapCanvasLight = Color(0xFFF0F0F5);
  static const mapCanvasCream = Color(0xFFF5F0E8);
  static const mapCanvasMint = Color(0xFFEDF5EF);
  static const mapCanvasIce = Color(0xFFEAF2F8);
  static const mapCanvasBlush = Color(0xFFF8EEF0);
  static const mapCanvasDark = Color(0xFF1C1C1E);
  static const mapCanvasMidnight = Color(0xFF0D1B2A);
  static const mapPickerBg = Color(0xFFD5D5D5);

  // Photo info / always-dark surfaces
  static const photoInfoBg = Color(0xFF1E1E1E);
  static const photoMapTile1 = Color(0xFF2C2C2E);
  static const photoMapTile2 = Color(0xFF1C1C1E);
}
