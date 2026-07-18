import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/frame/frame_style.dart';
import 'package:photo_map/features/gallery/utils/exif_reader.dart';

void main() {
  group('PhotoExif.isEmpty', () {
    test('default (all blank) is empty', () {
      expect(const PhotoExif().isEmpty, isTrue);
    });

    test('any core field present is not empty', () {
      expect(const PhotoExif(iso: '100').isEmpty, isFalse);
      expect(const PhotoExif(make: 'SONY').isEmpty, isFalse);
    });

    test('only display-derived fields still counts as empty', () {
      // camera/lens are derived display strings, not core EXIF presence.
      expect(const PhotoExif(camera: 'SONY ILCE-7C').isEmpty, isTrue);
    });
  });

  group('FrameStyle.id', () {
    test('stable ids', () {
      expect(FrameStyle.bottomBar.id, 'bottom_bar');
      expect(FrameStyle.fullBorder.id, 'full_border');
      expect(FrameStyle.minimal.id, 'minimal');
    });
  });

  group('FrameData.settingsLine', () {
    FrameData data(PhotoExif exif) =>
        FrameData(exif: exif, dateTime: DateTime(2024, 7, 28, 9, 3, 3));

    test('joins all present parts', () {
      final s = data(const PhotoExif(
        iso: '100',
        focalMm: '50',
        fNumber: '2.8',
        exposure: '1/1600s',
      )).settingsLine;
      expect(s, 'ISO100  50mm  F2.8  1/1600s');
    });

    test('omits unknown parts (never prints bare ISO/mm/F)', () {
      final s = data(const PhotoExif(iso: '100', exposure: '1/60s'))
          .settingsLine;
      expect(s, 'ISO100  1/60s');
    });

    test('all-blank exif yields an empty settings line', () {
      expect(data(const PhotoExif()).settingsLine, '');
    });
  });

  group('FrameData.timestampLine', () {
    test('zero-pads to camera style', () {
      final d = FrameData(
        exif: const PhotoExif(),
        dateTime: DateTime(2024, 7, 5, 9, 3, 3),
      );
      expect(d.timestampLine, '2024/07/05  09:03:03');
    });
  });

  group('FrameData.lensLine', () {
    test('prefers lensModel, falls back to derived lens', () {
      final withModel = FrameData(
        exif: const PhotoExif(lensModel: 'E 50mm F1.4', lens: '50mm — f/1.4'),
        dateTime: DateTime(2024),
      );
      expect(withModel.lensLine, 'E 50mm F1.4');

      final noModel = FrameData(
        exif: const PhotoExif(lens: '50mm — f/1.4'),
        dateTime: DateTime(2024),
      );
      expect(noModel.lensLine, '50mm — f/1.4');
    });
  });
}
