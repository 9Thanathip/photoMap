import 'dart:io';
import 'package:exif/exif.dart' as exif_lib;
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_map/core/theme/app_palette.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:photo_map/l10n/l10n_x.dart';
import '../../providers/gallery_notifier.dart';

class PhotoInfoContent extends StatefulWidget {
  const PhotoInfoContent({super.key, required this.photo});
  final PhotoItem photo;

  @override
  State<PhotoInfoContent> createState() => _PhotoInfoContentState();
}

class _PhotoInfoContentState extends State<PhotoInfoContent> {
  late final Future<Map<String, String>> _exifFuture;
  PhotoItem get photo => widget.photo;

  @override
  void initState() {
    super.initState();
    _exifFuture = _fetchTechnicalInfo(widget.photo.assetEntity);
  }

  Future<Map<String, String>> _fetchTechnicalInfo(AssetEntity? asset) async {
    if (asset == null) return {};
    try {
      if (asset.type == AssetType.video) {
        // Camera/lens are localized at display time via the fallback below.
        return {
          'iso': '—',
          'exposure': '—',
        };
      }

      final file = await asset.originFile ?? await asset.file;
      if (file == null) return {};

      final exif = await Exif.fromPath(file.path);
      final attr = await exif.getAttributes() ?? {};

      // Try reading Make/Model directly if not in bulk attributes
      String make = (attr['Make'] ?? attr['make'])?.toString().trim() ?? '';
      String model = (attr['Model'] ?? attr['model'])?.toString().trim() ?? '';

      if (make.isEmpty) {
        try { make = (await exif.getAttribute('Make'))?.trim() ?? ''; } catch (_) {}
      }
      if (model.isEmpty) {
        try { model = (await exif.getAttribute('Model'))?.trim() ?? ''; } catch (_) {}
      }

      await exif.close();

      // Fallback: read Make/Model via pure-Dart exif package from raw bytes
      if (make.isEmpty && model.isEmpty) {
        try {
          final bytes = await file.readAsBytes();
          final tags = await exif_lib.readExifFromBytes(bytes);
          make = tags['Image Make']?.printable.trim() ?? '';
          model = tags['Image Model']?.printable.trim() ?? '';
        } catch (_) {}
      }

      if (attr.isEmpty && make.isEmpty && model.isEmpty) return {};

      String cameraName = '';
      if (make.isNotEmpty && model.isNotEmpty) {
        if (model.toLowerCase().contains(make.toLowerCase())) {
          cameraName = model;
        } else {
          cameraName = '$make $model';
        }
      } else if (model.isNotEmpty) {
        cameraName = model;
      } else if (make.isNotEmpty) {
        cameraName = make;
      } else {
        cameraName = ''; // localized at display time
      }

      final focalLength = (attr['FocalLength'] ?? attr['focalLength'])?.toString() ?? '';
      final fNumber = (attr['FNumber'] ?? attr['fNumber'] ?? attr['ApertureValue'])?.toString() ?? '';
      final iso = (attr['ISOSpeedRatings'] ?? attr['isoSpeedRatings'] ?? attr['ISO'])?.toString() ?? '';
      final exposureTime = (attr['ExposureTime'] ?? attr['exposureTime'])?.toString() ?? '';

      String exposureStr = '0 ev';
      if (exposureTime.isNotEmpty) {
        final expNum = double.tryParse(exposureTime);
        if (expNum != null && expNum > 0) {
          if (expNum < 1) {
            final denom = (1 / expNum).round();
            exposureStr = '1/${denom}s';
          } else {
            exposureStr = '${expNum.toStringAsFixed(1)}s';
          }
        } else {
          exposureStr = exposureTime;
        }
      }

      double? parseRational(String value) {
        if (value.isEmpty) return null;
        if (value.contains('/')) {
          final parts = value.split('/');
          if (parts.length == 2) {
            final n = double.tryParse(parts[0].trim());
            final d = double.tryParse(parts[1].trim());
            if (n != null && d != null && d != 0) return n / d;
          }
        }
        return double.tryParse(value);
      }

      String focalLengthStr = '';
      if (focalLength.isNotEmpty) {
        final flNum = parseRational(focalLength);
        focalLengthStr = flNum != null ? flNum.toStringAsFixed(1) : focalLength;
      }

      String fNumberStr = '';
      if (fNumber.isNotEmpty) {
        final fnNum = parseRational(fNumber);
        fNumberStr = fnNum != null ? fnNum.toStringAsFixed(1) : fNumber;
      }

      String lensInfo = '';
      if (focalLengthStr.isNotEmpty && fNumberStr.isNotEmpty) {
        lensInfo = '${focalLengthStr}mm — f/$fNumberStr';
      } else if (focalLengthStr.isNotEmpty) {
        lensInfo = '${focalLengthStr}mm';
      } else if (fNumberStr.isNotEmpty) {
        lensInfo = 'f/$fNumberStr';
      } else {
        lensInfo = ''; // localized at display time
      }

      // Strip potential bracket formatting like [50] from ISO values
      String finalIso = iso.isNotEmpty 
          ? iso.replaceAll('[', '').replaceAll(']', '').trim() 
          : '—';

      return {
        'camera': cameraName,
        'lens': lensInfo,
        'iso': finalIso,
        'exposure': exposureStr,
      };
    } catch (e) {
      debugPrint('Error loading EXIF: $e');
      return {};
    }
  }

  Future<void> _launchMap(double lat, double lng, String label) async {
    final encoded = Uri.encodeComponent(label.isNotEmpty ? label : 'Photo');
    final appleMapsUrl = Uri.parse(
      'https://maps.apple.com/?ll=$lat,$lng&q=$encoded',
    );
    final geoIntent = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encoded)');
    final googleMapsWeb = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (Platform.isIOS) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(geoIntent)) {
          await launchUrl(geoIntent, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final day = date.day.toString();
    final month = l10n.monthsShort[date.month - 1];
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final weekday = l10n.weekdaysFull[date.weekday - 1];
    return '$weekday • $day $month $year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asset = photo.assetEntity;
    final mp = asset != null
        ? (asset.width * asset.height / 1000000).toStringAsFixed(1)
        : '0';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        160 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(photo.timestamp, l10n),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (asset?.title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        asset!.title!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // Technical Info Card (Loaded from EXIF)
          FutureBuilder<Map<String, String>>(
            future: _exifFuture,
            builder: (context, snapshot) {
              final info = snapshot.data ?? {};
              final isVideo = asset?.type == AssetType.video;
              final rawCamera = info['camera'];
              final camera = (rawCamera != null && rawCamera.isNotEmpty)
                  ? rawCamera
                  : (isVideo ? l10n.exifVideoRecording : l10n.exifUnknownCamera);
              final rawLens = info['lens'];
              final lens = (rawLens != null && rawLens.isNotEmpty)
                  ? rawLens
                  : (isVideo ? l10n.exifMainVideo : l10n.exifStandardLens);
              final iso = info['iso'] ?? '—';
              final exposure = info['exposure'] ?? '—';

              return Container(
                decoration: BoxDecoration(
                  color: Palette.photoInfoBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          asset?.type == AssetType.video
                              ? Icons.videocam_rounded
                              : Icons.camera_alt_rounded,
                          size: 20,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                camera,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                lens,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            asset?.mimeType?.split('/').last.toUpperCase() ??
                                'JPEG',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoDetail(
                          isVideo ? l10n.infoQuality : l10n.infoResolution,
                          isVideo
                              ? '4K • 60 fps'
                              : '$mp MP • ${asset?.width} × ${asset?.height}',
                          isDark,
                          flex: 2,
                        ),
                        _infoDetail(l10n.infoIso, iso, isDark),
                        _infoDetail(l10n.infoExposure, exposure, isDark),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Location Section — tap to open native Maps app
          if (photo.hasLocation) ...[
            Builder(builder: (context) {
              final title = photo.district.isNotEmpty
                  ? photo.district
                  : photo.province;
              final subtitle = [photo.province, photo.country]
                  .where((s) => s.isNotEmpty)
                  .join(', ');
              final hint = Platform.isIOS
                  ? l10n.openInAppleMaps
                  : l10n.openInGoogleMaps;
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _launchMap(photo.lat, photo.lng, title),
                  onVerticalDragStart: (_) {},
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Palette.photoMapTile1,
                            Palette.photoMapTile2,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title.isNotEmpty ? title : l10n.locationLabel,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.map_rounded,
                                      size: 12,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hint,
                                      style: GoogleFonts.inter(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
            }),
            SizedBox(
              height: 48 + MediaQuery.paddingOf(context).bottom,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoDetail(String label, String value, bool isDark, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
