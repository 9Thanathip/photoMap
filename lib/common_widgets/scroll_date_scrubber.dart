import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:photo_map/core/theme/app_tokens.dart';

/// How long the thumb and bubble stay up after the list stops moving.
const Duration _kLinger = Duration(milliseconds: 900);
const Duration _kFade = Duration(milliseconds: 160);

/// The painted thumb, and the invisible box you actually grab it by.
///
/// [RawScrollbar] gives a 6pt-wide target with no vertical slack, which on a
/// phone is a coin toss — a probe of this widget found a drag 6pt off the edge
/// scrolled the list instead of taking the thumb.
const double _kThumbWidth = 6;
const double _kThumbMinHeight = 44;
const double _kGrabWidth = 40;
const double _kGrabSlop = 10;

/// The thumb and the pill, for tests that check the two line up.
@visibleForTesting
const Key kScrubberThumbKey = Key('scrubber-thumb');
@visibleForTesting
const Key kScrubberBubbleKey = Key('scrubber-bubble');

/// What the scrubber is showing. [label] outlives [visible] on purpose —
/// dropping the text the moment scrolling stops would blank the pill before it
/// fades.
typedef _Scrub = ({
  String label,
  double fraction,
  double extentRatio,
  bool visible,
});

/// Gives [child] a draggable thumb, and floats a label beside it naming
/// whatever the viewport is currently over.
///
/// A library of thousands of photos is minutes of flinging otherwise: the
/// thumb turns that into one drag, and the label is what makes the drag
/// aimable — without it you are scrubbing blind.
///
/// ## Why not [RawScrollbar]
///
/// Two things it cannot do, both of which showed up as bugs.
///
/// Dragging its thumb past the top of the track keeps scrolling: on iOS and
/// Android the framework deliberately lets a scrollbar drag ride the bouncing
/// physics unbounded (`_getPrimaryDelta` in `scrollbar.dart` clamps on desktop
/// only). Overshooting by a finger's width took this gallery to -12000px —
/// every photo gone off the bottom of the screen.
///
/// And its thumb travels `fraction * (track - thumbExtent)` while an [Align]ed
/// bubble travels `fraction * (track - bubbleHeight)`. Two different equations
/// over the same fraction never line up. Here both come out of [_thumbFor], so
/// the pill points at the thumb by construction.
class ScrollDateScrubber extends StatefulWidget {
  const ScrollDateScrubber({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.child,
    this.labelFor,
    this.padding = EdgeInsets.zero,
  });

  final ScrollController controller;

  /// Items in the scrollable, in the order they appear.
  final int itemCount;

  /// Label for the span the viewport covers, from its top item to its bottom
  /// one. Null — or a null return — keeps the draggable thumb and shows no
  /// bubble, which is what an order with no meaningful dates wants.
  final String? Function(int first, int last)? labelFor;

  /// Keeps the thumb and the bubble clear of anything drawn over the list,
  /// such as a floating header. It is the track, so both are inset by it.
  final EdgeInsets padding;

  final Widget child;

  @override
  State<ScrollDateScrubber> createState() => _ScrollDateScrubberState();
}

class _ScrollDateScrubberState extends State<ScrollDateScrubber> {
  /// A notifier rather than setState: this changes every frame of a scroll,
  /// and rebuilding the grid underneath at that rate is exactly the stutter
  /// the rest of this screen was tuned to avoid.
  final ValueNotifier<_Scrub> _scrub =
      ValueNotifier((label: '', fraction: 0, extentRatio: 0, visible: false));
  Timer? _hide;

  /// Where the thumb has been dragged to, in track pixels. Held separately
  /// from the scroll position because it is clamped to the track — which is
  /// what stops a drag past the end from running away into overscroll.
  double? _dragTop;

  @override
  void dispose() {
    _hide?.cancel();
    _scrub.dispose();
    super.dispose();
  }

  // ── Scroll → state ──

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    // A horizontal TabBarView reports through the same listener.
    if (m.axis != Axis.vertical || !m.hasContentDimensions) return false;
    if (n is! ScrollUpdateNotification && n is! ScrollEndNotification) {
      return false;
    }

    final travel = m.maxScrollExtent - m.minScrollExtent;
    final span = travel + m.viewportDimension;
    final was = _scrub.value;
    _scrub.value = (
      label: _labelAt(m) ?? was.label,
      fraction: travel > 0
          ? ((m.pixels - m.minScrollExtent) / travel).clamp(0.0, 1.0)
          : 0.0,
      extentRatio: span > 0 ? (m.viewportDimension / span).clamp(0.0, 1.0) : 1.0,
      // Nothing to scrub when the content already fits.
      visible: travel > 0,
    );

    _hide?.cancel();
    if (_dragTop == null) {
      _hide = Timer(_kLinger, _fadeOut);
    }
    return false;
  }

  /// Which slice of the content the viewport sits over, mapped onto the item
  /// list. Exact for a uniform grid, and close enough under section headers
  /// that the date never reads as wrong.
  String? _labelAt(ScrollMetrics m) {
    final labelFor = widget.labelFor;
    final count = widget.itemCount;
    final span = m.maxScrollExtent + m.viewportDimension;
    if (labelFor == null || count <= 0 || span <= 0) return null;
    final first = ((m.pixels / span) * count).floor().clamp(0, count - 1);
    final last = ((((m.pixels + m.viewportDimension) / span) * count).ceil() - 1)
        .clamp(first, count - 1);
    return labelFor(first, last);
  }

  void _fadeOut() {
    final s = _scrub.value;
    _scrub.value = (
      label: s.label,
      fraction: s.fraction,
      extentRatio: s.extentRatio,
      visible: false,
    );
  }

  // ── Geometry ──

  /// The thumb's height and top edge within a track of [trackH].
  ///
  /// The single source both the thumb and the bubble are placed from.
  static ({double height, double top}) _thumbFor(double trackH, _Scrub s) {
    final min = math.min(_kThumbMinHeight, trackH);
    final height = (trackH * s.extentRatio).clamp(min, trackH);
    return (height: height, top: s.fraction * (trackH - height));
  }

  // ── Drag ──

  void _dragStart(double trackH) {
    _dragTop = _thumbFor(trackH, _scrub.value).top;
    _hide?.cancel();
  }

  void _dragUpdate(DragUpdateDetails d, double trackH) {
    final geo = _thumbFor(trackH, _scrub.value);
    final travel = trackH - geo.height;
    if (travel <= 0) return;

    // Clamped to the track, so overshooting the end has nowhere to go — the
    // whole point of not letting the framework map this drag for us.
    final top = ((_dragTop ?? geo.top) + d.delta.dy).clamp(0.0, travel);
    _dragTop = top;

    final c = widget.controller;
    if (!c.hasClients || c.positions.length != 1) return;
    final p = c.position;
    c.jumpTo(
      p.minScrollExtent + (top / travel) * (p.maxScrollExtent - p.minScrollExtent),
    );
  }

  void _dragEnd() {
    _dragTop = null;
    _hide?.cancel();
    _hide = Timer(_kLinger, _fadeOut);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned.fill(
          child: Padding(
            padding: widget.padding,
            child: LayoutBuilder(
              builder: (context, box) => ValueListenableBuilder<_Scrub>(
                valueListenable: _scrub,
                builder: (context, s, _) => _overlay(context, box.maxHeight, s),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _overlay(BuildContext context, double trackH, _Scrub s) {
    if (!trackH.isFinite || trackH <= 0) return const SizedBox.shrink();
    final t = context.tokens;
    final geo = _thumbFor(trackH, s);
    final centre = geo.top + geo.height / 2;

    return IgnorePointer(
      // A thumb that has faded out must not keep eating taps on the photos
      // underneath it.
      ignoring: !s.visible,
      child: AnimatedOpacity(
        opacity: s.visible ? 1 : 0,
        duration: _kFade,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (s.label.isNotEmpty)
              Positioned(
                top: centre,
                right: _kGrabWidth,
                child: IgnorePointer(
                  // Rides the thumb's centre. An Align would inset the pill by
                  // half its own height instead, and drift out of step.
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: _Bubble(key: kScrubberBubbleKey, text: s.label),
                  ),
                ),
              ),
            Positioned(
              top: geo.top - _kGrabSlop,
              right: 0,
              width: _kGrabWidth,
              height: geo.height + _kGrabSlop * 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // The thumb should follow the finger from where it landed, not
                // from 18pt later: a scrubber with a dead zone feels stuck.
                dragStartBehavior: DragStartBehavior.down,
                onVerticalDragStart: (_) => _dragStart(trackH),
                onVerticalDragUpdate: (d) => _dragUpdate(d, trackH),
                onVerticalDragEnd: (_) => _dragEnd(),
                onVerticalDragCancel: _dragEnd,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Container(
                      key: kScrubberThumbKey,
                      width: _kThumbWidth,
                      height: geo.height,
                      decoration: BoxDecoration(
                        color: t.textSecondary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(_kThumbWidth / 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: t.surfaceCard,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: t.glassShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
