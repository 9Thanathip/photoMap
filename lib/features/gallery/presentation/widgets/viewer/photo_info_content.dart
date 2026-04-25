import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_exif/native_exif.dart';
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

  static String? _cachedDeviceName;

  static Future<String> _getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      _cachedDeviceName = info.utsname.machine; // e.g. "iPhone15,2"
      // Map to marketing name if possible
      _cachedDeviceName = _iosModelName(info.utsname.machine);
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      _cachedDeviceName = '${info.brand} ${info.model}';
    } else {
      _cachedDeviceName = 'Unknown Camera';
    }
    return _cachedDeviceName!;
  }

  static String _iosModelName(String machine) {
    // Common iPhone models
    const map = {
      'iPhone10,3': 'iPhone X',
      'iPhone10,6': 'iPhone X',
      'iPhone11,2': 'iPhone XS',
      'iPhone11,4': 'iPhone XS Max',
      'iPhone11,6': 'iPhone XS Max',
      'iPhone11,8': 'iPhone XR',
      'iPhone12,1': 'iPhone 11',
      'iPhone12,3': 'iPhone 11 Pro',
      'iPhone12,5': 'iPhone 11 Pro Max',
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13',
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
      'iPhone17,3': 'iPhone 16',
      'iPhone17,4': 'iPhone 16 Plus',
      'iPhone17,5': 'iPhone 16e',
      'iPhone18,1': 'iPhone 17 Pro',
      'iPhone18,2': 'iPhone 17 Pro Max',
      'iPhone18,3': 'iPhone 17',
      'iPhone18,4': 'iPhone 17 Plus',
      'iPhone18,5': 'iPhone 17 Air',
    };
    final name = map[machine] ?? machine;
    return 'Apple $name';
  }

  Future<Map<String, String>> _fetchTechnicalInfo(AssetEntity? asset) async {
    if (asset == null) return {};
    try {
      if (asset.type == AssetType.video) {
        return {
          'camera': 'Video Recording',
          'lens': 'Main Camera — 4K 60fps',
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
        cameraName = await _getDeviceName();
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

      String focalLengthStr = '';
      if (focalLength.isNotEmpty) {
        final flNum = double.tryParse(focalLength);
        focalLengthStr = flNum != null ? flNum.toStringAsFixed(1) : focalLength;
      }

      String fNumberStr = '';
      if (fNumber.isNotEmpty) {
        final fnNum = double.tryParse(fNumber);
        fNumberStr = fnNum != null ? fnNum.toStringAsFixed(2) : fNumber;
      }

      String lensInfo = '';
      if (focalLengthStr.isNotEmpty && fNumberStr.isNotEmpty) {
        lensInfo = '${focalLengthStr}mm — f/$fNumberStr';
      } else if (focalLengthStr.isNotEmpty) {
        lensInfo = '${focalLengthStr}mm';
      } else if (fNumberStr.isNotEmpty) {
        lensInfo = 'f/$fNumberStr';
      } else {
        lensInfo = 'Standard Lens';
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

  Future<void> _launchMap(double lat, double lng) async {
    debugPrint('Attempting to launch map for: $lat, $lng');
    final googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );
    final appleMapsUrl = Uri.parse("maps://?q=$lat,$lng");

    try {
      if (Platform.isIOS) {
        if (await canLaunchUrl(appleMapsUrl)) {
          debugPrint('Launching Apple Maps');
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Apple Maps not available, trying Google Maps');
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        debugPrint('Launching Google Maps');
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
  }

  String _getWeekday(int day) {
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][day - 1];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString();
    final month = months[date.month - 1];
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_getWeekday(date.weekday)} • $day $month $year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      _formatDate(photo.timestamp),
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
              final camera = info['camera'] ??
                  (asset?.type == AssetType.video
                      ? 'Video Recording'
                      : 'Unknown Camera');
              final lens = info['lens'] ??
                  (asset?.type == AssetType.video
                      ? 'Main Video'
                      : 'Standard Lens');
              final iso = info['iso'] ?? '—';
              final exposure = info['exposure'] ?? '—';

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
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
                                Border.all(color: Colors.grey.withOpacity(0.3)),
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
                          asset?.type == AssetType.video
                              ? 'Quality'
                              : 'Resolution',
                          asset?.type == AssetType.video
                              ? '4K • 60 fps'
                              : '$mp MP • ${asset?.width} × ${asset?.height}',
                          isDark,
                          flex: 2,
                        ),
                        _infoDetail('ISO', iso, isDark),
                        _infoDetail('Exposure', exposure, isDark),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Location Section
          if (photo.hasLocation) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFF1E1E1E),
                child: Stack(
                  children: [
                    // Real Flutter Map
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(photo.lat, photo.lng),
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.photo_map.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(photo.lat, photo.lng),
                                  width: 80,
                                  height: 80,
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    // Map Overlay like Apple (IgnorePointer so taps pass through)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      photo.district.isNotEmpty
                                          ? photo.district
                                          : photo.province,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      [
                                        photo.province,
                                        photo.country,
                                      ].where((s) => s.isNotEmpty).join(', '),
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
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
                    ),
                    // Tap layer on top — absorbs vertical drags so the
                    // outer dismiss-gesture doesn't steal from taps.
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _launchMap(photo.lat, photo.lng),
                        onVerticalDragStart: (_) {},
                        onVerticalDragUpdate: (_) {},
                        onVerticalDragEnd: (_) {},
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 48 + MediaQuery.paddingOf(context).bottom,
            ), // More space at the very bottom
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
