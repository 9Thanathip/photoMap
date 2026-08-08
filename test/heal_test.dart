import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/features/gallery/presentation/widgets/editor/heal.dart';

/// Builds a 200x200 image: flat grey background with a red blob at the centre.
Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 200, 200),
    Paint()..color = const Color(0xFF808080),
  );
  canvas.drawRect(
    const Rect.fromLTWH(90, 90, 20, 20),
    Paint()..color = const Color(0xFFFF0000),
  );
  return recorder.endRecording().toImage(200, 200);
}

Future<List<int>> _pixelAt(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final i = (y * image.width + x) * 4;
  final bytes = data!.buffer.asUint8List();
  return [bytes[i], bytes[i + 1], bytes[i + 2]];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('heal replaces the painted area with surrounding texture', () async {
    final source = await _testImage();
    expect(await _pixelAt(source, 100, 100), [255, 0, 0]);

    final healed = await applyHeal(source, const [
      HealStroke(points: [Offset(0.5, 0.5)], radius: 0.09),
    ]);

    expect(identical(healed, source), isFalse,
        reason: 'a stroke should produce a new image');

    final centre = await _pixelAt(healed, 100, 100);
    expect(centre[0], lessThan(160), reason: 'red should be gone: $centre');
    expect((centre[0] - centre[1]).abs(), lessThan(24),
        reason: 'result should be neutral grey like its surroundings: $centre');
  });

  test('heal leaves the image untouched outside the stroke', () async {
    final source = await _testImage();
    final healed = await applyHeal(source, const [
      HealStroke(points: [Offset(0.5, 0.5)], radius: 0.09),
    ]);

    expect(await _pixelAt(healed, 10, 10), [128, 128, 128]);
  });

  test('a long drag is healed along its whole length', () async {
    // A bar spanning most of the frame — one patch this size has no matching
    // source anywhere, so this only works if the stroke is healed in segments.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..color = const Color(0xFF808080),
    );
    canvas.drawRect(
      const Rect.fromLTWH(30, 96, 140, 8),
      Paint()..color = const Color(0xFFFF0000),
    );
    final source = await recorder.endRecording().toImage(200, 200);

    final healed = await applyHeal(source, const [
      HealStroke(
        points: [Offset(0.16, 0.5), Offset(0.5, 0.5), Offset(0.84, 0.5)],
        radius: 0.035,
      ),
    ]);

    for (final x in [40, 100, 160]) {
      final px = await _pixelAt(healed, x, 100);
      expect(px[0], lessThan(160), reason: 'red left at x=$x: $px');
    }
  });

  test('no strokes returns the same instance', () async {
    final source = await _testImage();
    expect(identical(await applyHeal(source, const []), source), isTrue);
  });
}
