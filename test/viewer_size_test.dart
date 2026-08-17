import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/common_widgets/asset_thumb.dart';
import 'package:photo_map/common_widgets/asset_thumbnail_provider.dart';
import 'package:photo_map/common_widgets/photo_grid.dart';
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

  testWidgets('tile decode follows the grid density', (tester) async {
    final ctx = await _context(tester);
    // Coarser grid, bigger tiles, bigger decode — and vice versa. Sizing the
    // decode off a fixed column count would leave zoomed-out tiles blurry.
    expect(photoTileThumbSize(ctx, 2).width, greaterThan(400));
    expect(photoTileThumbSize(ctx, 8).width, lessThan(400));
  });

  group('thumbnail providers', () {
    test('the preview asks the platform for its cheapest rendition', () {
      final preview = assetPreviewProvider(_photo(3000, 4000));
      // Without `fast` the platform renders at full fidelity even for 128px,
      // and the preview stops beating the real tile — which is the entire
      // reason it exists.
      expect(preview.fast, isTrue);
      expect(preview.quality, lessThan(70));
      expect(preview.size.width, kThumbPreviewPixels);
      // JPEG here makes ImageIO log once per thumbnail, because PhotoKit hands
      // back an RGBA bitmap and JPEG has nowhere to put the alpha.
      expect(preview.format, ThumbnailFormat.png);
    });

    test('the disk key is filesystem-safe and edit-aware', () {
      // iOS asset ids contain '/', which would silently write outside the
      // cache directory (or fail) if it reached a filename raw.
      final key = AssetThumbnailProvider(
        AssetEntity(id: 'ABC-123/L0/001', typeInt: 1, width: 10, height: 10),
        size: const ThumbnailSize.square(400),
      ).diskCacheKey;
      expect(key, isNot(contains('/')));

      // Re-editing a photo keeps its id but bumps the modified date; without it
      // in the key the grid would keep serving the pre-edit thumbnail forever.
      String keyFor(int modified) => AssetThumbnailProvider(
            AssetEntity(
              id: 'same-id',
              typeInt: 1,
              width: 10,
              height: 10,
              modifiedDateSecond: modified,
            ),
            size: const ThumbnailSize.square(400),
          ).diskCacheKey;
      expect(keyFor(1000), isNot(keyFor(2000)));
    });

    test('a tile request never forces a full-fidelity decode', () {
      // The regression this guards. DeliveryMode.opportunistic looks unsafe —
      // it is the one mode PhotoKit answers twice, degraded pass first — but
      // photo_manager drops that pass rather than replying with it
      // (`isDownloadFinish` is `![info[PHImageResultIsDegradedKey] boolValue]`),
      // so the caller only ever sees the final image.
      //
      // Switching to highQualityFormat to be safe made every tile decode the
      // full-size original, all of it on the iOS main queue, which saturated
      // that queue and stopped the whole grid — previews included — from
      // rendering at all.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final tile = AssetThumbnailProvider.buildOption(
        const ThumbnailSize.square(400),
      ).toMap();
      expect(tile['deliveryMode'], isNot(DeliveryMode.highQualityFormat.index));
      // 'exact' would force a real resize per request on that same queue.
      expect(tile['resizeMode'], ResizeMode.fast.index);

      // The preview stays on the cheapest single-callback mode.
      final preview = AssetThumbnailProvider.buildOption(
        const ThumbnailSize.square(128),
        fast: true,
      ).toMap();
      expect(preview['deliveryMode'], DeliveryMode.fastFormat.index);
    });

    test('the cache key changed when the request did', () {
      // Entries written before the delivery-mode fix hold the degraded image.
      // Nothing in the old key described how the bytes were asked for, so
      // without a version they would be served as correct forever.
      final key = AssetThumbnailProvider(
        _photo(3000, 4000),
        size: const ThumbnailSize.square(400),
      ).diskCacheKey;
      expect(key, contains('_v3_'));
    });

    test('same asset and size is one cache entry', () {
      final asset = _photo(3000, 4000);
      const size = ThumbnailSize.square(400);
      expect(
        AssetThumbnailProvider(asset, size: size),
        AssetThumbnailProvider(asset, size: size),
      );
      // Differing on any request parameter has to be a different entry, or a
      // preview would be served where a sharp tile was asked for.
      expect(
        AssetThumbnailProvider(asset, size: size),
        isNot(AssetThumbnailProvider(asset, size: size, fast: true)),
      );
      expect(
        AssetThumbnailProvider(asset, size: size),
        isNot(AssetThumbnailProvider(asset,
            size: const ThumbnailSize.square(800))),
      );
    });
  });

  group('pinch snapping', () {
    test('spreading two fingers coarsens the grid', () {
      expect(gridColumnsForPinch(3, 1.6), 2); // 3 / 1.6 = 1.9 -> nearest is 2
      expect(gridColumnsForPinch(5, 1.7), 3);
      expect(gridColumnsForPinch(2, 4.0), 2); // already at the coarsest step
    });

    test('closing them makes tiles smaller', () {
      expect(gridColumnsForPinch(3, 0.6), 5); // 3 / 0.6 = 5
      expect(gridColumnsForPinch(5, 0.6), 8);
      expect(gridColumnsForPinch(8, 0.2), 8); // clamped at the finest step
    });

    test('a still pinch keeps the current density', () {
      for (final c in kGridColumnSteps) {
        expect(gridColumnsForPinch(c, 1.0), c);
      }
    });

    test('a degenerate span is ignored rather than snapping to a default', () {
      expect(gridColumnsForPinch(5, 0), 5);
      expect(gridColumnsForPinch(5, double.nan), 5);
    });
  });

  group('pinch zoom animation', () {
    // What the user sees is the laid-out tile size times the residual scale.
    double rendered(int startColumns, double pinch) {
      final columns = gridColumnsForPinch(startColumns, pinch);
      final scale = gridResidualScale(
        startColumns: startColumns,
        columns: columns,
        pinch: pinch,
      );
      return scale / columns;
    }

    test('tiles do not jump when the density steps', () {
      // 3 / 2.5 is the pinch factor where 3 columns gives way to 2. Either
      // side of it the layout differs by 1.5x and the residual by 1/1.5, so
      // the product — the size on screen — has to stay put.
      const threshold = 3 / 2.5;
      expect(
        rendered(3, threshold - 0.01),
        closeTo(rendered(3, threshold + 0.01), 0.01),
      );
    });

    test('resting at a step needs no scaling at all', () {
      for (final columns in kGridColumnSteps) {
        expect(
          gridResidualScale(
              startColumns: columns, columns: columns, pinch: 1.0),
          1.0,
        );
      }
    });

    test('past the last step it rubber-bands instead of running away', () {
      // Already at the coarsest density and still spreading.
      expect(
        gridResidualScale(startColumns: 2, columns: 2, pinch: 6.0),
        lessThan(2.0),
      );
      expect(
        gridResidualScale(startColumns: 8, columns: 8, pinch: 0.05),
        greaterThan(0.5),
      );
    });
  });
}
