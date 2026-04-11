import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapSettings {
  final Color provinceColor;
  final Color canvasColor;

  MapSettings({
    required this.provinceColor,
    required this.canvasColor,
  });

  MapSettings copyWith({
    Color? provinceColor,
    Color? canvasColor,
  }) => MapSettings(
    provinceColor: provinceColor ?? this.provinceColor,
    canvasColor: canvasColor ?? this.canvasColor,
  );
}

const _kKeyProvinceColor = 'map_province_color';
const _kKeyCanvasColor = 'map_canvas_color';

final mapSettingsProvider = StateNotifierProvider<MapSettingsNotifier, MapSettings>((ref) {
  return MapSettingsNotifier();
});

class MapSettingsNotifier extends StateNotifier<MapSettings> {
  MapSettingsNotifier() : super(MapSettings(
    provinceColor: const Color(0xFFD9D9D9),
    canvasColor: const Color(0xFFF0F0F5),
  )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getInt(_kKeyProvinceColor);
    final c = prefs.getInt(_kKeyCanvasColor);
    
    state = state.copyWith(
      provinceColor: p != null ? Color(p) : null,
      canvasColor: c != null ? Color(c) : null,
    );
  }

  Future<void> updateProvinceColor(Color color) async {
    state = state.copyWith(provinceColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKeyProvinceColor, color.value);
  }

  Future<void> updateCanvasColor(Color color) async {
    state = state.copyWith(canvasColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKeyCanvasColor, color.value);
  }
}
