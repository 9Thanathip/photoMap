import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photos_tab.dart';
import 'package:photo_map/features/gallery/presentation/widgets/viewer/image_viewer_page.dart';

/// A 3x phone: 400x800 logical, so the panel is 1200x2400 physical.
const _phone = MediaQueryData(size: Size(400, 800), devicePixelRatio: 3);

AssetEntity _photo(int w, int h) =>
    AssetEntity(id: '$w-$h', typeInt: 1, width: w, height: h);

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MediaQuery(
      data: _phone,
      child: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return ctx;
}

void main() {
  testWidgets('viewer sizes the decode to the box the photo fills',
      (tester) async {
    final ctx = await _context(tester);

    // 3:4 portrait letterboxes to the full width: 400 x 533 logical.
    final portrait = viewerDisplaySize(ctx, _photo(3000, 4000));
    expect(portrait.width, 1664); // 533 * 3, rounded up to the 128 step

    // 4:3 landscape only covers 400 x 300, so it needs far less.
    final landscape = viewerDisplaySize(ctx, _photo(4000, 3000));
    expect(landscape.width, 1280);

    // Both stay well under what sizing off the screen's long edge asked for
    // (800 * 3 * 1.5 = 3600) — that surplus was the open-photo stutter.
    expect(portrait.width, lessThan(3600));
    expect(landscape.width, lessThan(portrait.width));
  });

  testWidgets('pinching in buys a sharper decode, capped', (tester) async {
    final ctx = await _context(tester);
    final base = viewerDisplaySize(ctx, _photo(3000, 4000));
    final zoomed = viewerDisplaySize(ctx, _photo(3000, 4000), scale: 2.0);
    expect(zoomed.width, greaterThan(base.width));
    expect(zoomed.width, 2560); // clamped rather than unbounded
  });

  testWidgets('a missing asset falls back to the whole screen', (tester) async {
    final ctx = await _context(tester);
    expect(viewerBox(ctx, null), const Size(400, 800));
  });

  testWidgets('the viewer placeholder matches the grid tile exactly',
      (tester) async {
    final ctx = await _context(tester);
    // (400 - 1.5*2) / 3 = 132.3 logical -> 397 px -> stepped to 400.
    // Any drift here means the Hero flight decodes the thumbnail a second time.
    expect(photoTileThumbSize(ctx).width, 400);
    expect(photoTileThumbSize(ctx).height, 400);
  });
}
