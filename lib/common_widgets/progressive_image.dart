import 'dart:async';

import 'package:flutter/material.dart';

/// Paints a cheap [preview] decode immediately and crossfades to [image] once
/// the real one is ready, then drops the preview.
///
/// ## Why the preview is warmed by hand
///
/// [Image] wraps whatever provider it is given in a `ScrollAwareImageProvider`,
/// which **refuses to start any load** while
/// `Scrollable.recommendDeferredLoadingForContext` is true — that is, for the
/// whole duration of a fling. So simply handing it a smaller provider changes
/// nothing: during a fast scroll neither tier loads, and the instant scrolling
/// stops every visible tile fires at once, which is the burst that stutters.
///
/// That same code takes an early exit when the key is already in
/// [PaintingBinding.imageCache]. So the preview is pushed into the cache with
/// [precacheImage], which is *not* scroll-aware — and the widget then paints it
/// mid-fling. The sharp tier is left scroll-aware on purpose: it is the
/// expensive one, and it should wait until the list settles.
class ProgressiveImage extends StatefulWidget {
  const ProgressiveImage({
    super.key,
    required this.preview,
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
  });

  final ImageProvider preview;
  final ImageProvider image;
  final BoxFit fit;
  final Alignment alignment;

  /// Quality for the sharp pass. The preview is always drawn at
  /// [FilterQuality.low] — it is upscaled and about to be replaced.
  final FilterQuality filterQuality;

  /// Shown while even the preview is still decoding.
  final Widget? placeholder;

  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

const Duration _kFade = Duration(milliseconds: 180);

/// How long a tile has to stay alive before its preview is worth fetching.
///
/// A tile crossing the screen mid-fling is built and disposed well inside this
/// window, so a fast scroll no longer queues a platform request for every row
/// it flies past — only for the ones that linger long enough to be looked at.
const Duration _kPreviewWarmup = Duration(milliseconds: 80);

class _ProgressiveImageState extends State<ProgressiveImage> {
  /// True once a sharp layer fully covers the tile, at which point keeping the
  /// preview in the tree only costs a second fill of it.
  bool _covered = false;

  /// The sharp image from before [ProgressiveImage.image] last changed, held
  /// underneath so the new one has something to cross-fade *from*.
  ///
  /// Changing the provider on a single [Image] cannot fade: `gaplessPlayback`
  /// holds the old frame and then swaps it in one go. Regridding after a pinch
  /// asks for a differently sized decode of every visible photo, and that hard
  /// swap across a screenful of tiles is what reads as a flicker.
  ImageProvider? _outgoing;

  Timer? _warmup;

  @override
  void initState() {
    super.initState();
    _scheduleWarmup();
  }

  @override
  void didUpdateWidget(ProgressiveImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image && _covered) {
      // Keep the first outgoing image across a burst of changes — pinching
      // through several densities must not hand over to a half-faded layer.
      _outgoing ??= old.image;
    }
    if (old.preview != widget.preview) {
      _scheduleWarmup();
    }
  }

  @override
  void dispose() {
    _warmup?.cancel();
    super.dispose();
  }

  void _scheduleWarmup() {
    _warmup?.cancel();
    _warmup = Timer(_kPreviewWarmup, () {
      if (!mounted) return;
      // Deliberately not through the Image widget: precacheImage skips the
      // scroll-aware wrapper, so this is the one load that can happen while
      // the list is still moving.
      precacheImage(widget.preview, context, onError: (_, _) {});
    });
  }

  /// The new decode is fully opaque: nothing underneath it can be seen, so
  /// stop paying to paint it.
  void _settled() {
    if (!mounted || (_covered && _outgoing == null)) return;
    setState(() {
      _covered = true;
      _outgoing = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoing;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_covered)
          Image(
            image: widget.preview,
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return widget.placeholder ?? const SizedBox.shrink();
            },
            errorBuilder: (_, error, _) {
              // Silence here is why a broken pipeline looked like an empty
              // grid with a clean log.
              debugPrint('ProgressiveImage: preview failed: $error');
              return widget.placeholder ?? const SizedBox.shrink();
            },
          ),
        if (outgoing != null)
          Image(
            image: outgoing,
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        Image(
          // Keyed by the provider so each new decode starts its fade from zero
          // instead of resuming whatever the last one was part-way through.
          key: ValueKey<ImageProvider>(widget.image),
          image: widget.image,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          frameBuilder: (context, child, frame, wasSync) {
            final ready = wasSync || frame != null;
            if (ready && wasSync) {
              // Already cached: there is no fade to wait on, and AnimatedOpacity
              // never fires onEnd when its value doesn't change.
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _settled());
            }
            return AnimatedOpacity(
              opacity: ready ? 1.0 : 0.0,
              duration: wasSync ? Duration.zero : _kFade,
              onEnd: ready ? _settled : null,
              child: child,
            );
          },
          // Leave whatever is underneath showing rather than painting an error
          // box over it — but say so, or a tile that never loads is
          // indistinguishable from one that is still loading.
          errorBuilder: (_, error, _) {
            debugPrint('ProgressiveImage: image failed: $error');
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
