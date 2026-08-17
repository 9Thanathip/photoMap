import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_map/core/services/thumb_prefetcher.dart';

import 'asset_thumb.dart';
import 'asset_thumbnail_provider.dart';

/// Densities a photo grid snaps between when pinched, coarse to fine.
const List<int> kGridColumnSteps = [2, 3, 5, 8];

/// Default density, and what every grid uses until the user pinches.
const int kPhotoGridColumns = 3;

const double kPhotoGridSpacing = 1.5;

/// Upper bound for a grid tile's decode. Only bites at the coarsest density on
/// a very large display.
const int kPhotoTileMaxPixels = 800;

SliverGridDelegate photoGridDelegate([int columns = kPhotoGridColumns]) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: kPhotoGridSpacing,
      mainAxisSpacing: kPhotoGridSpacing,
    );

/// The exact pixel size a grid tile asks for at [columns].
///
/// The viewer reuses it for its placeholder and Hero flight image: a different
/// size is a different cache key, so asking for anything else starts a fresh
/// decode in the middle of the open animation — which is precisely when there
/// is no budget for one. That is also why grid density is app-wide rather than
/// per-screen: one number, one cache entry per photo.
ThumbnailSize photoTileThumbSize(
  BuildContext context, [
  int columns = kPhotoGridColumns,
]) {
  final width = MediaQuery.sizeOf(context).width;
  final tile = (width - kPhotoGridSpacing * (columns - 1)) / columns;
  return assetThumbPx(context, Size(tile, tile),
      maxPixels: kPhotoTileMaxPixels);
}

/// Snaps a continuous zoom factor onto [kGridColumnSteps]. Spreading two
/// fingers ([scale] > 1) grows the tiles, which means fewer columns.
int gridColumnsForPinch(int fromColumns, double scale) {
  if (scale <= 0 || !scale.isFinite) return fromColumns;
  final target = fromColumns / scale;
  var best = kGridColumnSteps.first;
  var bestDelta = double.infinity;
  for (final c in kGridColumnSteps) {
    final delta = (c - target).abs();
    if (delta >= bestDelta) continue;
    bestDelta = delta;
    best = c;
  }
  return best;
}

/// Tells the platform which photos the grid is heading towards, so their
/// renditions are being prepared before a tile asks for one.
///
/// Takes an index-based accessor rather than a list of assets: a fling emits a
/// notification per frame, and materialising a few thousand entities each time
/// would cost more than the prefetch saves. Only the window is ever touched.
class GridPrefetch extends StatefulWidget {
  const GridPrefetch({
    super.key,
    required this.itemCount,
    required this.assetAt,
    required this.thumbSize,
    required this.child,
  });

  final int itemCount;
  final AssetEntity? Function(int index) assetAt;
  final ThumbnailSize thumbSize;
  final Widget child;

  @override
  State<GridPrefetch> createState() => _GridPrefetchState();
}

class _GridPrefetchState extends State<GridPrefetch> {
  /// Roughly three screens of a 3-wide grid ahead, one behind — enough to stay
  /// in front of a fling without asking for half the library.
  static const int _ahead = 60;
  static const int _behind = 20;

  /// The band whose cheap previews are pushed into Flutter's image cache,
  /// measured along the direction of travel.
  ///
  /// Lopsided because a fling only ever arrives from one side: spending the
  /// budget symmetrically means warming rows the user has already gone past.
  static const int _previewAhead = 36;
  static const int _previewBehind = 8;

  /// Where the viewport was last time, to tell which way it is going.
  double _lastPixels = 0;

  @override
  void dispose() {
    ThumbPrefetcher.instance.stop();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // A horizontal TabBarView reports through the same listener.
    if (n.metrics.axis != Axis.vertical || widget.itemCount == 0) return false;
    final m = n.metrics;
    if (!m.hasContentDimensions) return false;

    // Fraction of the whole content the viewport's centre is over. Using the
    // scrollable extent alone would land short at the bottom of the list.
    final span = m.maxScrollExtent + m.viewportDimension;
    if (span <= 0) return false;
    final centre =
        (((m.pixels + m.viewportDimension / 2) / span) * widget.itemCount)
            .round();

    final start = (centre - _behind).clamp(0, widget.itemCount);
    final end = (centre + _ahead).clamp(0, widget.itemCount);
    final assets = <AssetEntity>[
      for (var i = start; i < end; i++) ?widget.assetAt(i),
    ];
    final goingDown = m.pixels >= _lastPixels;
    _lastPixels = m.pixels;
    final lead = goingDown ? _previewAhead : _previewBehind;
    final trail = goingDown ? _previewBehind : _previewAhead;
    final previewStart = (centre - trail).clamp(0, widget.itemCount);
    final previewEnd = (centre + lead).clamp(0, widget.itemCount);
    ThumbPrefetcher.instance.warm(
      assets,
      widget.thumbSize,
      onReady: (_) => unawaited(_warmPreviews(previewStart, previewEnd)),
    );
    return false;
  }

  /// Bumped whenever a new band is warmed, so the previous walk stops.
  int _warmGeneration = 0;

  /// Decodes the cheap previews for the band around the viewport ahead of time.
  ///
  /// This is what stops a fling showing empty tiles. [Image] wraps every
  /// provider in a `ScrollAwareImageProvider`, which refuses to start a load
  /// while a list is moving fast and only takes its early exit when the key is
  /// already in [PaintingBinding.imageCache] — so a tile that scrolls into view
  /// mid-fling can only paint something if that something was cached before it
  /// was built. [precacheImage] is not scroll-aware, which makes it the one way
  /// to get it in there.
  ///
  /// Walked one at a time rather than fired off together. Every one of these is
  /// a PhotoKit request, and photo_manager services those on the iOS main
  /// thread — sixty at once is the main queue held for sixty encodes, which
  /// costs more than the warming saves. One at a time keeps the queue free for
  /// the tiles that are actually on screen, and the generation check drops the
  /// rest of a band the moment the viewport has moved past it.
  Future<void> _warmPreviews(int start, int end) async {
    // Nothing paints the preview tier when it is switched off, so warming it
    // would be a platform request per photo that no tile ever asks for.
    if (!mounted ||
        !ThumbPipeline.progressive ||
        !ThumbPipeline.previewPrefetch) {
      return;
    }
    final generation = ++_warmGeneration;
    for (var i = start; i < end; i++) {
      if (!mounted || generation != _warmGeneration) return;
      final asset = widget.assetAt(i);
      if (asset == null) continue;
      await precacheImage(
        assetPreviewProvider(asset),
        context,
        onError: (_, _) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}

/// Extra scale the laid-out grid still needs to match where the fingers are.
///
/// Density only moves in steps while a pinch is continuous, and this is what
/// reconciles them: at [columns] the tiles are already `startColumns / columns`
/// times bigger, so only the leftover factor gets drawn. Crossing a step grows
/// the layout by exactly the amount this drops, which is why the tiles the user
/// sees never jump — only their crispness changes, once the new decodes land.
///
/// Clamped, so holding a pinch past the coarsest or finest step rubber-bands
/// instead of running away.
double gridResidualScale({
  required int startColumns,
  required int columns,
  required double pinch,
}) {
  if (startColumns <= 0 || !pinch.isFinite) return 1.0;
  return (pinch * columns / startColumns).clamp(0.6, 1.7);
}

/// Pinch-to-resize for a photo grid, the way iOS Photos does it.
///
/// Runs on raw pointer events instead of a scale recognizer on purpose:
/// [ScaleGestureRecognizer] also accepts on focal-point movement, so it would
/// win the gesture arena against the scroll view and kill one-finger
/// scrolling. A [Listener] never competes. Scrolling is suspended for the
/// duration of the pinch by handing the builder a different [ScrollPhysics],
/// which rebuilds the ScrollPosition and drops any drag already in flight.
class GridPinchZoom extends StatefulWidget {
  const GridPinchZoom({
    super.key,
    required this.columns,
    required this.onColumns,
    required this.builder,
  });

  final int columns;
  final ValueChanged<int> onColumns;

  /// Must hand [controller] and [physics] to the scrollable it returns —
  /// the controller is what keeps the same photos in view across a density
  /// change, and the physics is what stops the list scrolling mid-pinch.
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    ScrollPhysics? physics,
  ) builder;

  @override
  State<GridPinchZoom> createState() => _GridPinchZoomState();
}

/// How long the grid takes to ease back to its real size once the fingers lift.
const Duration _kSettle = Duration(milliseconds: 200);

class _GridPinchZoomState extends State<GridPinchZoom> {
  final _scroll = ScrollController();
  final Map<int, Offset> _points = {};
  double? _startSpan;
  int? _startColumns;

  /// Live zoom applied on top of the laid-out grid, so the tiles track the
  /// fingers between the discrete density steps. 1.0 whenever idle.
  double _scale = 1.0;

  bool get _pinching => _startSpan != null;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double? _span() {
    if (_points.length < 2) return null;
    final it = _points.values.iterator;
    it.moveNext();
    final a = it.current;
    it.moveNext();
    return (a - it.current).distance;
  }

  void _tryStart() {
    if (_pinching) return;
    final span = _span();
    if (span == null || span < 1) return;
    setState(() {
      _startSpan = span;
      _startColumns = widget.columns;
    });
  }

  void _onDown(PointerDownEvent event) {
    _points[event.pointer] = event.position;
    _tryStart();
  }

  void _onMove(PointerMoveEvent event) {
    if (!_points.containsKey(event.pointer)) return;
    _points[event.pointer] = event.position;
    if (!_pinching) {
      _tryStart();
      return;
    }
    final span = _span();
    if (span == null) return;
    final raw = span / _startSpan!;
    final next = gridColumnsForPinch(_startColumns!, raw);
    if (next != widget.columns) {
      HapticFeedback.selectionClick();
      _anchor(widget.columns, next);
      widget.onColumns(next);
    }
    setState(() {
      _scale = gridResidualScale(
        startColumns: _startColumns!,
        columns: next,
        pinch: raw,
      );
    });
  }

  void _onRelease(int pointer) {
    _points.remove(pointer);
    if (_points.length >= 2 || !_pinching) return;
    setState(() {
      _startSpan = null;
      _startColumns = null;
      // Settles back to the real layout size; see the AnimatedScale in build.
      _scale = 1.0;
    });
  }

  /// Keeps roughly the same photo at the top across a density change.
  ///
  /// Content height goes as `photos / columns²` (fewer rows, each shorter), so
  /// the offset has to be scaled by the inverse. Without this, going from 3 to
  /// 8 columns shortens the list ~7x and the view slams into the bottom.
  void _anchor(int from, int to) {
    if (!_scroll.hasClients) return;
    final target = _scroll.offset * (from * from) / (to * to);
    // maxScrollExtent is only correct once the new layout has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (e) => _onRelease(e.pointer),
      onPointerCancel: (e) => _onRelease(e.pointer),
      // Clipped because a scale below 1 pulls the grid in from the edges, and
      // above 1 pushes rows out past them.
      child: ClipRect(
        child: AnimatedScale(
          // Zero while the fingers are down: the scale *is* the gesture, and
          // interpolating it would lag behind the pinch. On release it becomes
          // an animation, easing the residual back out as the real layout
          // takes over.
          duration: _pinching ? Duration.zero : _kSettle,
          curve: Curves.easeOutCubic,
          scale: _scale,
          filterQuality: FilterQuality.low,
          child: widget.builder(
            context,
            _scroll,
            _pinching ? const NeverScrollableScrollPhysics() : null,
          ),
        ),
      ),
    );
  }
}
