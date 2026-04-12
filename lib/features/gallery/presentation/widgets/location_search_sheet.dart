import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_notifier.dart';

// ── Nominatim place model ─────────────────────────────────────────────────────

class _Place {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  const _Place({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  factory _Place.fromJson(Map<String, dynamic> json) {
    final parts = (json['display_name'] as String).split(', ');
    return _Place(
      displayName: json['display_name'] as String,
      shortName: parts.first,
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
    );
  }
}

// ── Nominatim search ──────────────────────────────────────────────────────────

Future<List<_Place>> _searchPlaces(String query) async {
  if (query.trim().isEmpty) return [];
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'json',
    'limit': '10',
    'accept-language': 'th,en',
  });
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    request.headers.set('User-Agent', 'PhotoMap/1.0');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();
    final list = json.decode(body) as List<dynamic>;
    return list.map((e) => _Place.fromJson(e as Map<String, dynamic>)).toList();
  } finally {
    client.close();
  }
}

// ── Write GPS EXIF to photo file ──────────────────────────────────────────────

Future<bool> _writeGpsToPhoto(
  PhotoItem photo,
  double lat,
  double lng,
) async {
  final entity = photo.assetEntity;
  if (entity == null) return false;

  // Use .file (not .originFile) — photo_manager converts HEIC → JPEG on iOS,
  // which native_exif can reliably write GPS metadata to.
  final file = await entity.file;
  if (file == null) return false;

  // Copy to a writable temp path with .jpg extension
  final tempDir = Directory.systemTemp;
  final tempPath = '${tempDir.path}/photmap_loc_${entity.id}.jpg';
  final tempFile = await file.copy(tempPath);

  try {
    final exif = await Exif.fromPath(tempFile.path);
    await exif.writeAttributes({
      'GPSLatitude': lat.abs().toString(),
      'GPSLatitudeRef': lat >= 0 ? 'N' : 'S',
      'GPSLongitude': lng.abs().toString(),
      'GPSLongitudeRef': lng >= 0 ? 'E' : 'W',
    });
    await exif.close();

    // Save from file path — preserves EXIF metadata written above
    final saved = await PhotoManager.editor.saveImageWithPath(
      tempFile.path,
      title: entity.title ?? 'photo',
    );
    return saved != null;
  } finally {
    if (await tempFile.exists()) await tempFile.delete();
  }
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class LocationSearchSheet extends ConsumerStatefulWidget {
  const LocationSearchSheet({super.key, required this.photo});

  final PhotoItem photo;

  @override
  ConsumerState<LocationSearchSheet> createState() =>
      _LocationSearchSheetState();
}

class _LocationSearchSheetState extends ConsumerState<LocationSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_Place> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() { _results = []; _error = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await _searchPlaces(query);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Cannot connect. Check internet connection.';
        });
      }
    }
  }

  void _select(_Place place) {
    _focusNode.unfocus();

    // Update in-app state immediately and close — EXIF write runs in background
    ref.read(galleryStateProvider.notifier).updatePhotoLocation(
          widget.photo.path,
          widget.photo.country.isEmpty ? 'Unknown' : widget.photo.country,
          place.shortName,
        );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    Navigator.pop(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Setting location to ${place.shortName}…'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Write GPS EXIF in background
    _writeGpsToPhoto(widget.photo, place.lat, place.lng).then((success) {
      if (success) {
        ref.read(galleryStateProvider.notifier).silentReload();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to write GPS to photo file'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: errorColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Push sheet up when keyboard appears
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Set Location',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'Search place…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _controller.clear();
                              setState(() { _results = []; _error = null; });
                            },
                          )
                        : _loading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withAlpha(80)),

              // Results
              Expanded(
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : _results.isEmpty && !_loading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withAlpha(80)),
                                const SizedBox(height: 12),
                                Text(
                                  _controller.text.isEmpty
                                      ? 'Search for a place'
                                      : 'No results found',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length,
                            separatorBuilder: (context, i) => Divider(
                              height: 1,
                              indent: 56,
                              color:
                                  theme.colorScheme.outlineVariant.withAlpha(60),
                            ),
                            itemBuilder: (_, i) {
                              final place = _results[i];
                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.location_on_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary),
                                ),
                                title: Text(
                                  place.shortName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  place.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () => _select(place),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
