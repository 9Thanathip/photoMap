import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapSettings {
  final Color provinceColor;
  final Color canvasColor;
  final Color strokeColor;
  final double strokeWidth; // 0.3 – 3.0

  MapSettings({
    required this.provinceColor,
    required this.canvasColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  MapSettings copyWith({
    Color? provinceColor,
    Color? canvasColor,
    Color? strokeColor,
    double? strokeWidth,
  }) => MapSettings(
    provinceColor: provinceColor ?? this.provinceColor,
    canvasColor: canvasColor ?? this.canvasColor,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
  );
}

const _kKeyProvinceColor = 'map_province_color';
const _kKeyCanvasColor = 'map_canvas_color';
const _kKeyStrokeColor = 'map_stroke_color';
const _kKeyStrokeWidth = 'map_stroke_width';

final mapSettingsProvider =
    StateNotifierProvider<MapSettingsNotifier, MapSettings>(
  (ref) => MapSettingsNotifier(),
);

class MapSettingsNotifier extends StateNotifier<MapSettings> {
  MapSettingsNotifier()
      : super(MapSettings(
          provinceColor: const Color(0xFFD9D9D9),
          canvasColor: const Color(0xFFF0F0F5),
          strokeColor: Colors.white,
          strokeWidth: 0.8,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      provinceColor: prefs.containsKey(_kKeyProvinceColor)
          ? Color(prefs.getInt(_kKeyProvinceColor)!)
          : null,
      canvasColor: prefs.containsKey(_kKeyCanvasColor)
          ? Color(prefs.getInt(_kKeyCanvasColor)!)
          : null,
      strokeColor: prefs.containsKey(_kKeyStrokeColor)
          ? Color(prefs.getInt(_kKeyStrokeColor)!)
          : null,
      strokeWidth: prefs.getDouble(_kKeyStrokeWidth),
    );
  }

  Future<void> updateProvinceColor(Color color) async {
    state = state.copyWith(provinceColor: color);
    (await SharedPreferences.getInstance())
        .setInt(_kKeyProvinceColor, color.toARGB32());
  }

  Future<void> updateCanvasColor(Color color) async {
    state = state.copyWith(canvasColor: color);
    (await SharedPreferences.getInstance())
        .setInt(_kKeyCanvasColor, color.toARGB32());
  }

  Future<void> updateStrokeColor(Color color) async {
    state = state.copyWith(strokeColor: color);
    (await SharedPreferences.getInstance())
        .setInt(_kKeyStrokeColor, color.toARGB32());
  }

  Future<void> updateStrokeWidth(double width) async {
    state = state.copyWith(strokeWidth: width);
    (await SharedPreferences.getInstance())
        .setDouble(_kKeyStrokeWidth, width);
  }
}
