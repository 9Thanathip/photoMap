import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/frame/camera_logo.dart';

void main() {
  group('CameraLogo.assetKey', () {
    test('direct brand hit (case-insensitive, trimmed)', () {
      expect(CameraLogo.assetKey('SONY'), 'sony');
      expect(CameraLogo.assetKey('  Canon '), 'canon');
      expect(CameraLogo.assetKey('apple'), 'apple');
    });

    test('aliases collapse to a canonical key', () {
      expect(CameraLogo.assetKey('NIKON CORPORATION'), 'nikon');
      expect(CameraLogo.assetKey('OM Digital Solutions'), 'olympus');
      expect(CameraLogo.assetKey('LEICA CAMERA AG'), 'leica');
    });

    test('falls back to the first token', () {
      expect(CameraLogo.assetKey('NIKON D850'), 'nikon');
      expect(CameraLogo.assetKey('Canon EOS R5'), 'canon');
    });

    test('empty or unknown make returns null', () {
      expect(CameraLogo.assetKey(''), isNull);
      expect(CameraLogo.assetKey('   '), isNull);
      expect(CameraLogo.assetKey('NoSuchBrand'), isNull);
    });
  });

  group('CameraLogo.wordmark', () {
    test('uppercases the make', () {
      expect(CameraLogo.wordmark('sony'), 'SONY');
      expect(CameraLogo.wordmark('Fujifilm'), 'FUJIFILM');
    });
  });
}
