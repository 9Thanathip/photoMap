import 'dart:io';
import 'package:photo_map/core/theme/app_icons.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import '../../providers/gallery_notifier.dart';
import '../../../utils/exif_reader.dart';
import 'camera_logo.dart';
import 'frame_painter.dart';
import 'frame_style.dart';

/// Full-screen editor that wraps a single photo in an EXIF frame and exports
/// it (save to Photos + share). Preview and export share one [paintFrame] so
/// what the user sees is exactly what's written.
class FrameExportScreen extends StatefulWidget {
  const FrameExportScreen({super.key, required this.photo});

  final PhotoItem photo;

  @override
  State<FrameExportScreen> createState() => _FrameExportScreenState();
}

class _FrameExportScreenState extends State<FrameExportScreen> {
  FrameStyle _style = FrameStyle.bottomBar;
  double _textScale = 1.0;
  double _frameScale = 1.0;

  /// Which export action is running (''/'save'/'share') — drives the per-button
  /// spinner and disables both while busy.
  String _busy = '';

  ui.Image? _photoImage;
  ui.Image? _logo;
  FrameData? _data;
  bool _loadError = false;

  /// Encoded PNG cached by layout key, so tapping Save right after Share (or
  /// re-tapping the same action) skips the expensive re-render + encode.
  Uint8List? _pngCache;
  String? _pngCacheKey;

  /// Longest edge of the exported image. Full-camera resolution (48MP) is
  /// needlessly slow to PNG-encode for a share/save; capping keeps it snappy
  /// with no visible quality loss at social sizes.
  static const double _maxExportEdge = 3000;

  String get _layoutKey => '${_style.id}|$_textScale|$_frameScale';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _photoImage?.dispose();
    _logo?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final asset = widget.photo.assetEntity;
    if (asset == null) {
      setState(() => _loadError = true);
      return;
    }
    try {
      final bytes = await asset.originBytes;
      if (bytes == null) throw StateError('Original bytes unavailable.');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      final exif = await readPhotoExif(asset);
      final logo = exif.make.isNotEmpty ? await loadCameraLogo(exif.make) : null;

      if (!mounted) {
        frame.image.dispose();
        logo?.dispose();
        return;
      }
      setState(() {
        _photoImage = frame.image;
        _logo = logo;
        _data = FrameData(exif: exif, dateTime: widget.photo.timestamp);
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  Future<ui.Image> _render() async {
    final photo = _photoImage!;
    final data = _data!;
    final geo = computeFrameGeometry(
      _style,
      Size(photo.width.toDouble(), photo.height.toDouble()),
      frameScale: _frameScale,
    );
    // Cap the output so PNG encoding stays fast on 48MP originals.
    final longest = geo.canvasSize.longestSide;
    final scale = longest > _maxExportEdge ? _maxExportEdge / longest : 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & geo.canvasSize);
    if (scale != 1.0) canvas.scale(scale);
    paintFrame(canvas,
        photo: photo,
        data: data,
        style: _style,
        geo: geo,
        logo: _logo,
        textScale: _textScale);
    final picture = recorder.endRecording();
    return picture.toImage(
      (geo.canvasSize.width * scale).round(),
      (geo.canvasSize.height * scale).round(),
    );
  }

  /// Encodes the current frame to PNG, reusing [_pngCache] when the layout
  /// hasn't changed since the last export.
  Future<Uint8List?> _renderPng() async {
    if (_pngCache != null && _pngCacheKey == _layoutKey) return _pngCache;
    final image = await _render();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final png = bytes?.buffer.asUint8List();
    _pngCache = png;
    _pngCacheKey = _layoutKey;
    return png;
  }

  Future<void> _save() async {
    if (_busy.isNotEmpty || _photoImage == null || _data == null) return;
    setState(() => _busy = 'save');
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      final png = await _renderPng();
      if (png == null) throw StateError('Failed to encode frame.');
      final filename = 'jaruek_frame_${DateTime.now().millisecondsSinceEpoch}.png';
      await PhotoManager.editor.saveImage(
        png,
        filename: filename,
        title: filename,
        desc: 'Framed in Jaruek',
      );
      AppSnack.showOnOverlay(overlay, l10n.frameSaved);
    } catch (_) {
      AppSnack.showOnOverlay(overlay, l10n.frameSaveFailed,
          type: AppSnackType.error);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Future<void> _share() async {
    if (_busy.isNotEmpty || _photoImage == null || _data == null) return;
    setState(() => _busy = 'share');
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      final png = await _renderPng();
      if (png == null) throw StateError('Failed to encode frame.');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/jaruek_frame_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      AppSnack.showOnOverlay(overlay, l10n.frameSaveFailed,
          type: AppSnackType.error);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.surfaceBase,
        // bottom: false so our own bottom padding is the only inset — keeps the
        // action bar flush with the screen edge (matches the collage builder).
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(l10n, t),
              Expanded(child: _buildPreview(l10n, t)),
              _buildStylePicker(l10n, t),
              _buildSliders(l10n, t),
              _buildActions(l10n, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, AppTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: t.textSecondary),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            l10n.frameTitle,
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _buildPreview(AppLocalizations l10n, AppTokens t) {
    if (_loadError) {
      return Center(
        child: Text(l10n.frameSaveFailed,
            style: TextStyle(color: t.textSecondary)),
      );
    }
    final photo = _photoImage;
    final data = _data;
    if (photo == null || data == null) {
      return Center(
        child:
            CircularProgressIndicator(color: t.textPrimary, strokeWidth: 2),
      );
    }
    final geo = computeFrameGeometry(
      _style,
      Size(photo.width.toDouble(), photo.height.toDouble()),
      frameScale: _frameScale,
    );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: AspectRatio(
          aspectRatio: geo.canvasSize.width / geo.canvasSize.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: t.glassShadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CustomPaint(
              painter: FramePainter(
                photo: photo,
                data: data,
                style: _style,
                geo: geo,
                logo: _logo,
                textScale: _textScale,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStylePicker(AppLocalizations l10n, AppTokens t) {
    String label(FrameStyle s) => switch (s) {
          FrameStyle.bottomBar => l10n.frameStyleBottomBar,
          FrameStyle.fullBorder => l10n.frameStyleFullBorder,
          FrameStyle.minimal => l10n.frameStyleMinimal,
        };
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final s in FrameStyle.values)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _style = s);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _style == s ? t.textPrimary : t.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label(s),
                  style: TextStyle(
                    color: _style == s ? t.surfaceBase : t.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliders(AppLocalizations l10n, AppTokens t) {
    final enabled = _photoImage != null && _busy.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          _scaleRow(
            t,
            l10n.frameTextSize,
            _textScale,
            0.7,
            1.5,
            enabled ? (v) => setState(() => _textScale = v) : null,
          ),
          if (_style != FrameStyle.minimal)
            _scaleRow(
              t,
              l10n.frameSize,
              _frameScale,
              0.6,
              1.6,
              enabled ? (v) => setState(() => _frameScale = v) : null,
            ),
        ],
      ),
    );
  }

  Widget _scaleRow(
    AppTokens t,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(color: t.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: t.textPrimary,
              inactiveTrackColor: t.textTertiary,
              thumbColor: t.textPrimary,
              overlayColor: t.textPrimary.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n, AppTokens t) {
    final ready = _photoImage != null && _data != null && _busy.isEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: ready ? _share : null,
              icon: _busy == 'share'
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: t.textPrimary),
                    )
                  : const Icon(AppIcons.ios_share_rounded, size: 18),
              label: Text(l10n.frameShare),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textPrimary,
                side: BorderSide(color: t.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: ready ? _save : null,
              icon: _busy == 'save'
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: t.surfaceBase),
                    )
                  : const Icon(AppIcons.download_rounded, size: 18),
              label: Text(l10n.frameSave),
              style: FilledButton.styleFrom(
                backgroundColor: t.textPrimary,
                foregroundColor: t.surfaceBase,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
