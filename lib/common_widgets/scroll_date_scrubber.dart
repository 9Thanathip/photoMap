import 'dart:async';

import 'package:flutter/material.dart';

import 'package:photo_map/core/theme/app_tokens.dart';

/// How long the bubble stays up after the list stops moving.
const Duration _kLinger = Duration(milliseconds: 900);
const Duration _kFade = Duration(milliseconds: 160);

/// What the bubble is showing. [label] outlives [visible] on purpose — dropping
/// the text the moment scrolling stops would blank the pill before it fades.
typedef _Scrub = ({String label, double fraction, bool visible});

/// Gives [child] a scrollbar whose thumb can be dragged, and floats a label
/// beside it naming whatever the viewport is currently over.
///
/// A library of thousands of photos is minutes of flinging otherwise: the
/// thumb turns that into one drag, and the label is what makes the drag
/// aimable — without it you are scrubbing blind.
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
  /// such as a floating header. Both are inset by it, so they stay level with
  /// each other.
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
      ValueNotifier((label: '', fraction: 0, visible: false));
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    _scrub.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    // A horizontal TabBarView reports through the same listener.
    if (m.axis != Axis.vertical || !m.hasContentDimensions) return false;
    if (n is! ScrollUpdateNotification && n is! ScrollEndNotification) {
      return false;
    }

    final count = widget.itemCount;
    final labelFor = widget.labelFor;
    final span = m.maxScrollExtent + m.viewportDimension;
    if (labelFor != null && count > 0 && span > 0) {
      // Which slice of the content the viewport sits over, mapped onto the
      // item list. Exact for a uniform grid, and close enough under section
      // headers that the date never reads as wrong.
      final first =
          ((m.pixels / span) * count).floor().clamp(0, count - 1);
      final last = ((((m.pixels + m.viewportDimension) / span) * count).ceil() -
              1)
          .clamp(first, count - 1);
      final label = labelFor(first, last);
      if (label != null) {
        final travel = m.maxScrollExtent;
        _scrub.value = (
          label: label,
          fraction: travel > 0 ? (m.pixels / travel).clamp(0.0, 1.0) : 0.0,
          visible: true,
        );
      }
    }

    _hide?.cancel();
    _hide = Timer(_kLinger, () {
      final last = _scrub.value;
      _scrub.value = (
        label: last.label,
        fraction: last.fraction,
        visible: false,
      );
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        // Raw rather than the Material Scrollbar because only this one takes a
        // padding: the Material one always tracks the full viewport, which
        // started the thumb up behind the header while the bubble began below
        // it, and the two never lined up.
        RawScrollbar(
          controller: widget.controller,
          padding: widget.padding,
          // Off by default on touch platforms, and it is the whole point here.
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          thumbColor: t.textSecondary.withValues(alpha: 0.55),
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: widget.padding,
            child: IgnorePointer(
              child: ValueListenableBuilder<_Scrub>(
                valueListenable: _scrub,
                builder: (context, scrub, _) => AnimatedOpacity(
                  opacity: scrub.visible ? 1 : 0,
                  duration: _kFade,
                  child: Align(
                    // -1 is the top of the box, 1 the bottom: the same travel
                    // the thumb makes, so the bubble rides alongside it.
                    alignment: Alignment(1, scrub.fraction * 2 - 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: _Bubble(text: scrub.label),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

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
