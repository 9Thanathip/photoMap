import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'package:photo_map/common_widgets/app_snack.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/core/services/boundary_export.dart';
import '../providers/country_provider.dart';
import '../providers/map_provider.dart';
import '../providers/map_settings_provider.dart';
import '../widgets/thailand_map_painter.dart';

/// Social share card: the painted country map plus travel stats in a
/// portrait 4:5 layout (Instagram-friendly), exported via RepaintBoundary.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() => captureBoundaryPng(_cardKey);

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await _capture();
      if (bytes == null) throw StateError('capture failed');
      final filename =
          'jaruek_card_${DateTime.now().millisecondsSinceEpoch}.png';
      await PhotoManager.editor.saveImage(
        bytes,
        filename: filename,
        title: filename,
        desc: 'Share card from Jaruek',
      );
      if (mounted) AppSnack.success(context, l10n.mapSavedToPhotos);
    } catch (_) {
      if (mounted) AppSnack.error(context, l10n.mapSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/jaruek_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      // Share sheet dismissal and IO failures are both non-fatal here.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final map = ref.watch(mapProvider);
    final settings = ref.watch(mapSettingsProvider);
    final country = ref.watch(countryProvider).current;
    final photos = ref.watch(galleryStateProvider).allPhotos;

    final isTh = Localizations.localeOf(context).languageCode == 'th';
    final countryName = isTh ? country.nameTh : country.nameEn;

    final total = map.provinces.length;
    final visited = map.provincePhotos.keys.length;
    final percent = total == 0 ? 0 : (visited / total * 100).round();
    final photoCount =
        photos.where((p) => p.country == country.nameEn).length;

    // Static paint times so the card renders fully opaque — the map screen's
    // reveal animation must not leak into the export.
    final done = DateTime(2000);
    final staticTimes = {
      for (final k in map.provincePhotos.keys) k: done,
    };
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF101013),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          l10n.shareCardTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            settings.canvasColor,
                            Color.lerp(settings.canvasColor, Colors.black,
                                0.35)!,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final onDark = ThemeData.estimateBrightnessForColor(
                                  settings.canvasColor) ==
                              Brightness.dark;
                          final fg = onDark ? Colors.white : Colors.black87;
                          final fgDim = fg.withValues(alpha: 0.6);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countryName,
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.shareCardProvinces(visited, total),
                                style: TextStyle(color: fgDim, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Center(
                                  child: CustomPaint(
                                    size: Size.square(box.maxWidth - 48),
                                    painter: ThailandMapPainter(
                                      provinces: map.provinces,
                                      combinedPath: map.combinedPath,
                                      provincePhotos: map.provincePhotos,
                                      imageLoadTimes: staticTimes,
                                      cropRects: map.cropRects,
                                      currentTime: now,
                                      openTime: done,
                                      baseColor: settings.provinceColor,
                                      strokeColor: settings.strokeColor,
                                      strokeWidth: settings.strokeWidth,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Progress
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: total == 0 ? 0 : visited / total,
                                  minHeight: 6,
                                  backgroundColor:
                                      fg.withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(fg),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    l10n.shareCardExplored(percent),
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    l10n.shareCardPhotos(photoCount),
                                    style:
                                        TextStyle(color: fgDim, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'JARUEK',
                                    style: TextStyle(
                                      color: fgDim,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                  Text(
                                    '${now.day}.${now.month}.${now.year}',
                                    style:
                                        TextStyle(color: fgDim, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Actions ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: AppIcons.download_rounded,
                      label: l10n.tooltipSaveToPhotos,
                      onTap: _busy ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: AppIcons.ios_share,
                      label: l10n.tooltipShare,
                      onTap: _busy ? null : _share,
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: filled
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }
}
