import 'package:exif/exif.dart' as exif_lib;
import 'package:flutter/foundation.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';

/// Parsed camera metadata for a single photo, shared by the viewer info panel
/// and the frame exporter. Raw numeric parts (make/model/focalMm/fNumber) are
/// kept alongside the pre-formatted display strings so callers can compose
/// their own layout (e.g. `ISO100 50mm F2.8 1/1600s`).
@immutable
class PhotoExif {
  const PhotoExif({
    this.make = '',
    this.model = '',
    this.lensModel = '',
    this.camera = '',
    this.lens = '',
    this.iso = '',
    this.exposure = '',
    this.focalMm = '',
    this.fNumber = '',
  });

  /// Camera maker, e.g. `SONY`.
  final String make;

  /// Camera body, e.g. `ILCE-7C`.
  final String model;

  /// Lens description from EXIF, e.g. `E 50mm F1.4`.
  final String lensModel;

  /// Display camera name (`make model`, de-duplicated), or '' when unknown.
  final String camera;

  /// Display lens summary, e.g. `50mm — f/1.4`, or '' when unknown.
  final String lens;

  /// ISO value without brackets, e.g. `100`. '—' when unknown.
  final String iso;

  /// Shutter speed, e.g. `1/1600s`. '' when unknown.
  final String exposure;

  /// Focal length in millimetres as a bare number, e.g. `50`. '' when unknown.
  final String focalMm;

  /// Aperture f-number as a bare number, e.g. `2.8`. '' when unknown.
  final String fNumber;

  bool get isEmpty =>
      make.isEmpty &&
      model.isEmpty &&
      iso.isEmpty &&
      exposure.isEmpty &&
      focalMm.isEmpty &&
      fNumber.isEmpty;
}

/// Reads and normalises EXIF metadata from a [AssetEntity].
///
/// Falls back from the platform `native_exif` reader to the pure-Dart `exif`
/// package for Make/Model, mirroring what the viewer info panel needs. Never
/// throws — returns an empty [PhotoExif] on any failure.
Future<PhotoExif> readPhotoExif(AssetEntity? asset) async {
  if (asset == null || asset.type == AssetType.video) {
    return const PhotoExif();
  }

  try {
    final file = await asset.originFile ?? await asset.file;
    if (file == null) return const PhotoExif();

    final exif = await Exif.fromPath(file.path);
    final attr = await exif.getAttributes() ?? {};

    String make = (attr['Make'] ?? attr['make'])?.toString().trim() ?? '';
    String model = (attr['Model'] ?? attr['model'])?.toString().trim() ?? '';
    String lensModel =
        (attr['LensModel'] ?? attr['lensModel'])?.toString().trim() ?? '';

    if (make.isEmpty) {
      try {
        make = (await exif.getAttribute('Make'))?.trim() ?? '';
      } catch (_) {}
    }
    if (model.isEmpty) {
      try {
        model = (await exif.getAttribute('Model'))?.trim() ?? '';
      } catch (_) {}
    }

    await exif.close();

    // Fallback: read Make/Model via pure-Dart exif from raw bytes.
    if (make.isEmpty && model.isEmpty) {
      try {
        final bytes = await file.readAsBytes();
        final tags = await exif_lib.readExifFromBytes(bytes);
        make = tags['Image Make']?.printable.trim() ?? '';
        model = tags['Image Model']?.printable.trim() ?? '';
        lensModel = lensModel.isNotEmpty
            ? lensModel
            : (tags['EXIF LensModel']?.printable.trim() ?? '');
      } catch (_) {}
    }

    String cameraName;
    if (make.isNotEmpty && model.isNotEmpty) {
      cameraName = model.toLowerCase().contains(make.toLowerCase())
          ? model
          : '$make $model';
    } else if (model.isNotEmpty) {
      cameraName = model;
    } else if (make.isNotEmpty) {
      cameraName = make;
    } else {
      cameraName = '';
    }

    final focalLength =
        (attr['FocalLength'] ?? attr['focalLength'])?.toString() ?? '';
    final fNumber =
        (attr['FNumber'] ?? attr['fNumber'] ?? attr['ApertureValue'])
                ?.toString() ??
            '';
    final iso = (attr['ISOSpeedRatings'] ??
                attr['isoSpeedRatings'] ??
                attr['ISO'])
            ?.toString() ??
        '';
    final exposureTime =
        (attr['ExposureTime'] ?? attr['exposureTime'])?.toString() ?? '';

    String exposureStr = '';
    if (exposureTime.isNotEmpty) {
      final expNum = double.tryParse(exposureTime);
      if (expNum != null && expNum > 0) {
        exposureStr = expNum < 1
            ? '1/${(1 / expNum).round()}s'
            : '${expNum.toStringAsFixed(1)}s';
      } else {
        exposureStr = exposureTime;
      }
    }

    final focalMm = _formatRational(focalLength);
    final fNum = _formatRational(fNumber);

    String lens;
    if (focalMm.isNotEmpty && fNum.isNotEmpty) {
      lens = '${focalMm}mm — f/$fNum';
    } else if (focalMm.isNotEmpty) {
      lens = '${focalMm}mm';
    } else if (fNum.isNotEmpty) {
      lens = 'f/$fNum';
    } else {
      lens = '';
    }

    final finalIso = iso.isNotEmpty
        ? iso.replaceAll('[', '').replaceAll(']', '').trim()
        : '';

    return PhotoExif(
      make: make,
      model: model,
      lensModel: lensModel,
      camera: cameraName,
      lens: lens,
      iso: finalIso,
      exposure: exposureStr,
      focalMm: focalMm,
      fNumber: fNum,
    );
  } catch (e) {
    debugPrint('Error loading EXIF: $e');
    return const PhotoExif();
  }
}

/// Parses an EXIF rational (`"50/1"`) or plain number into a trimmed decimal
/// string like `50` or `2.8`. Returns '' for empty/invalid input.
String _formatRational(String value) {
  if (value.isEmpty) return '';
  double? parsed;
  if (value.contains('/')) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final n = double.tryParse(parts[0].trim());
      final d = double.tryParse(parts[1].trim());
      if (n != null && d != null && d != 0) parsed = n / d;
    }
  }
  parsed ??= double.tryParse(value);
  if (parsed == null) return value;
  // Drop trailing .0 (50.0 -> 50) but keep 2.8.
  return parsed == parsed.roundToDouble()
      ? parsed.toStringAsFixed(0)
      : parsed.toStringAsFixed(1);
}
