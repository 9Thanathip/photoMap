import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/color_matrix_utils.dart';

enum _EditMode { presets, adjust }

enum _AdjustTool { exposure, contrast, saturation, temperature, tint }

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({
    super.key,
    required this.photo,
    required this.heroTag,
  });

  final PhotoItem photo;
  final String heroTag;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  _EditMode _mode = _EditMode.presets;
  _AdjustTool? _activeTool;

  // State
  int _presetIndex = 0;
  double _exposure = 0.0; // -1.0 to 1.0
  double _contrast = 1.0; // 0.5 to 1.5
  double _saturation = 1.0; // 0.0 to 2.0
  double _temperature = 0.0; // -1.0 to 1.0
  double _tint = 0.0; // -1.0 to 1.0

  bool _showOriginal = false;

  ColorMatrix get _combinedMatrix {
    if (_showOriginal) return ColorMatrix.identity;

    ColorMatrix m = kFilmPresets[_presetIndex].matrix;
    if (_exposure != 0) m = m.multiply(ColorMatrix.exposure(_exposure));
    if (_contrast != 1.0) m = m.multiply(ColorMatrix.contrast(_contrast));
    if (_saturation != 1.0) m = m.multiply(ColorMatrix.saturation(_saturation));
    if (_temperature != 0) m = m.multiply(ColorMatrix.temperature(_temperature));
    if (_tint != 0) m = m.multiply(ColorMatrix.tint(_tint));

    return m;
  }

  void _resetAdjustments() {
    setState(() {
      _exposure = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _temperature = 0.0;
      _tint = 0.0;
    });
  }

  bool get _hasAdjustments =>
      _exposure != 0.0 ||
      _contrast != 1.0 ||
      _saturation != 1.0 ||
      _temperature != 0.0 ||
      _tint != 0.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _buildImageViewport(),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          Text(
            _mode == _EditMode.presets ? 'Presets' : 'Adjust',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Save to gallery or apply to map state
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewport() {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showOriginal = true),
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: widget.photo.assetEntity != null
              ? ColorFiltered(
                  colorFilter: ColorFilter.matrix(_combinedMatrix.matrix),
                  child: Hero(
                    tag: widget.heroTag,
                    child: Image(
                      image: AssetEntityImageProvider(
                        widget.photo.assetEntity!,
                        isOriginal: true,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _mode == _EditMode.presets
                    ? _buildPresetsList()
                    : (_activeTool != null
                        ? _buildSlider()
                        : _buildAdjustTools()),
              ),
            ),
          ),
          if (_activeTool == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomTab(
                    title: 'PRESETS',
                    isActive: _mode == _EditMode.presets,
                    onTap: () => setState(() => _mode = _EditMode.presets),
                  ),
                  _BottomTab(
                    title: 'ADJUST',
                    isActive: _mode == _EditMode.adjust,
                    onTap: () => setState(() => _mode = _EditMode.adjust),
                    showDot: _hasAdjustments,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetsList() {
    return ListView.builder(
      key: const ValueKey('presets'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: kFilmPresets.length,
      itemBuilder: (context, i) {
        final preset = kFilmPresets[i];
        final isSelected = _presetIndex == i;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _presetIndex = i);
          },
          child: Container(
            width: 72,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preset.id,
                  style: GoogleFonts.manrope(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 2 : 4),
                    child: widget.photo.assetEntity != null
                        ? ColorFiltered(
                            colorFilter: ColorFilter.matrix(preset.matrix.matrix),
                            child: Image(
                              image: AssetEntityImageProvider(
                                widget.photo.assetEntity!,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(100),
                              ),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdjustTools() {
    return ListView(
      key: const ValueKey('tools'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      children: [
        _ToolButton(
          icon: Icons.exposure_rounded,
          label: 'Exposure',
          isActive: _exposure != 0,
          onTap: () => setState(() => _activeTool = _AdjustTool.exposure),
        ),
        _ToolButton(
          icon: Icons.contrast_rounded,
          label: 'Contrast',
          isActive: _contrast != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.contrast),
        ),
        _ToolButton(
          icon: Icons.water_drop_outlined,
          label: 'Saturation',
          isActive: _saturation != 1.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.saturation),
        ),
        _ToolButton(
          icon: Icons.thermostat_rounded,
          label: 'Temperature',
          isActive: _temperature != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.temperature),
        ),
        _ToolButton(
          icon: Icons.invert_colors_rounded,
          label: 'Tint',
          isActive: _tint != 0.0,
          onTap: () => setState(() => _activeTool = _AdjustTool.tint),
        ),
        const SizedBox(width: 24),
        if (_hasAdjustments)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _resetAdjustments();
            },
            icon: const Icon(Icons.settings_backup_restore_rounded,
                color: Colors.white54),
            tooltip: 'Reset Adjustments',
          ),
      ],
    );
  }

  Widget _buildSlider() {
    double value = 0;
    double min = -1.0;
    double max = 1.0;
    String label = '';

    switch (_activeTool!) {
      case _AdjustTool.exposure:
        value = _exposure;
        label = 'Exposure';
        break;
      case _AdjustTool.contrast:
        min = 0.5;
        max = 1.5;
        value = _contrast;
        label = 'Contrast';
        break;
      case _AdjustTool.saturation:
        min = 0.0;
        max = 2.0;
        value = _saturation;
        label = 'Saturation';
        break;
      case _AdjustTool.temperature:
        value = _temperature;
        label = 'Temperature';
        break;
      case _AdjustTool.tint:
        value = _tint;
        label = 'Tint';
        break;
    }

    return Column(
      key: const ValueKey('slider'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _activeTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTool = null),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                setState(() {
                  switch (_activeTool!) {
                    case _AdjustTool.exposure:
                      _exposure = v;
                      break;
                    case _AdjustTool.contrast:
                      _contrast = v;
                      break;
                    case _AdjustTool.saturation:
                      _saturation = v;
                      break;
                    case _AdjustTool.temperature:
                      _temperature = v;
                      break;
                    case _AdjustTool.tint:
                      _tint = v;
                      break;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.title,
    required this.isActive,
    required this.onTap,
    this.showDot = false,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: showDot
                    ? (isActive ? Colors.white : Colors.white38)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
