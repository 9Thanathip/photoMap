import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../providers/gallery_notifier.dart';
import '../main_gallery/photos_tab.dart' show photoTileThumbSize;


/// Logical size the photo actually occupies on screen: it is letterboxed to
/// fit, so a landscape shot on a portrait phone covers a fraction of it.
Size viewerBox(BuildContext context, AssetEntity? asset) {
  final screen = MediaQuery.sizeOf(context);
  final w = asset?.orientatedWidth ?? 0;
  final h = asset?.orientatedHeight ?? 0;
  if (w <= 0 || h <= 0) return screen;
  return applyBoxFit(
    BoxFit.contain,
    Size(w.toDouble(), h.toDouble()),
    screen,
  ).destination;
}

/// Full-viewer size in **pixels** for the box the photo really fills.
///
/// Sizing off the screen's long edge (and then padding it for zoom headroom)
/// asked for 4–9x more pixels than the panel can show: on a 3x phone a
/// portrait photo was decoded at ~11 MP / 44 MB when 2 MP / 8 MB is pixel
/// exact. That surplus is what made opening a photo stutter — every one of
/// them cost a large resize on the platform side, a large decode, and a large
/// texture upload.
///
/// Rounded up to [_sizeStep] so a few logical pixels of layout difference
/// don't spawn a second decode and cache entry for the same photo.
const int _sizeStep = 128;
const int _minSide = 640;
const int _maxSide = 2560;

ThumbnailSize viewerDisplaySize(
  BuildContext context,
  AssetEntity? asset, {
  double scale = 1.0,
}) {
  final box = viewerBox(context, asset);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final raw = math.max(box.width, box.height) * dpr * scale;
  final side =
      ((raw / _sizeStep).ceil() * _sizeStep).clamp(_minSide, _maxSide);
  return ThumbnailSize(side, side);
}

/// Zoom past this and the base image is being upscaled enough to see, so a
/// sharper one is fetched — only for the photo actually being inspected.
const double _kHiResZoom = 1.8;
const double _kHiResScale = 2.0;

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.photo,
    required this.onZoomChanged,
    required this.onTap,
    this.alignment = Alignment.center,
    this.heroTag,
  });

  final PhotoItem photo;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;
  final Alignment alignment;
  final String? heroTag;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

/// Deliberately not kept alive: every page the user swiped past used to hold a
/// full-screen decode for the life of the viewer, so memory (and jank) grew
/// with each swipe. Off-screen pages are disposed; the decodes stay in
/// [PaintingBinding.imageCache], which is what makes coming back cheap.
class _ImageViewerPageState extends State<ImageViewerPage>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  bool _isZoomed = false;
  bool _hiRes = false;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onAnimationUpdate);
  }

  void _onTransform() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.1;
    if (zoomed != _isZoomed) {
      // setState so InteractiveViewer.panEnabled updates this frame —
      // otherwise pan stays disabled until an unrelated rebuild lands.
      setState(() => _isZoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
    // One-way: once the sharper frame is paid for, keep it for this page
    // rather than thrashing the decoder as the pinch crosses the threshold.
    if (!_hiRes && scale > _kHiResZoom) {
      setState(() => _hiRes = true);
    }
  }

  void _onAnimationUpdate() {
    if (_animation != null) {
      _controller.value = _animation!.value;
    }
  }

  void _handleDoubleTap() {
    final Matrix4 matrix = _controller.value;
    final double scale = matrix.getMaxScaleOnAxis();

    _animationController.stop();

    if (scale > 1.1) {
      // Zoom out
      _animation = Matrix4Tween(begin: matrix, end: Matrix4.identity()).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      // Zoom in at tap position
      final position = _doubleTapPosition ?? Offset.zero;
      final Matrix4 zoomedMatrix = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 2.5, 1);

      _animation = Matrix4Tween(begin: matrix, end: zoomedMatrix).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
    }

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photo.assetEntity == null) {
      return const Center(
        child: Icon(AppIcons.broken_image, color: Colors.white, size: 64),
      );
    }

    final asset = widget.photo.assetEntity!;

    // Placeholder + Hero flight image. Byte-for-byte the size the grid tile
    // asked for — a different size is a different cache key, so anything else
    // starts a fresh decode while the Hero is mid-flight, which is exactly
    // when there is no budget for one.
    final thumbProvider = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: photoTileThumbSize(context),
    );

    // Display-resolution provider, sized to the box this photo actually
    // covers. Only a page the user has pinched into pays for the sharper one.
    final fullProvider = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: viewerDisplaySize(
        context,
        asset,
        scale: _hiRes ? _kHiResScale : 1.0,
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _isZoomed,
        child: Align(
          alignment: widget.alignment,
          child: AspectRatio(
            aspectRatio:
                widget.photo.assetEntity!.orientatedWidth > 0 &&
                    widget.photo.assetEntity!.orientatedHeight > 0
                ? widget.photo.assetEntity!.orientatedWidth /
                      widget.photo.assetEntity!.orientatedHeight
                : 1.0,
            child: Hero(
              tag: widget.heroTag ?? widget.photo.path,
              flightShuttleBuilder:
                  (
                    BuildContext flightContext,
                    Animation<double> animation,
                    HeroFlightDirection flightDirection,
                    BuildContext fromHeroContext,
                    BuildContext toHeroContext,
                  ) {
                    return Material(
                      color: Colors.transparent,
                      child: Image(
                        image: thumbProvider,
                        fit: BoxFit.cover,
                        alignment: widget.alignment,
                      ),
                    );
                  },
              child: _TwoPhaseImage(
                thumbProvider: thumbProvider,
                fullProvider: fullProvider,
                alignment: widget.alignment,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the small thumbnail instantly, then crossfades to full-res once decoded.
/// If full-res fails to load (some Android photos), stays on thumbnail.
class _TwoPhaseImage extends StatefulWidget {
  const _TwoPhaseImage({
    required this.thumbProvider,
    required this.fullProvider,
    required this.alignment,
  });

  final ImageProvider thumbProvider;
  final ImageProvider fullProvider;
  final Alignment alignment;

  @override
  State<_TwoPhaseImage> createState() => _TwoPhaseImageState();
}

class _TwoPhaseImageState extends State<_TwoPhaseImage> {
  bool _fullLoaded = false;
  bool _fullFailed = false;
  /// True once the crossfade has finished, at which point the thumbnail is
  /// fully hidden behind the full-res frame — keeping it in the tree only buys
  /// a second full-screen texture composited on every frame.
  bool _fullOpaque = false;
  ImageStreamListener? _listener;
  ImageStream? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveFullImage();
  }

  @override
  void didUpdateWidget(_TwoPhaseImage old) {
    super.didUpdateWidget(old);
    // The provider swaps when a pinch asks for the sharper decode. Keep the
    // loaded flags as they are: the Image is gapless, so the frame on screen
    // stays put until the bigger one arrives.
    if (old.fullProvider != widget.fullProvider) {
      _fullFailed = false;
      _resolveFullImage();
    }
  }

  void _resolveFullImage() {
    // Clean up previous listener
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }

    _listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!mounted || _fullLoaded) return;
        // Already decoded and cached (revisiting a page): show it straight
        // away instead of replaying the fade.
        if (synchronousCall) {
          _fullLoaded = true;
          _fullOpaque = true;
          return;
        }
        setState(() => _fullLoaded = true);
      },
      onError: (error, stackTrace) {
        debugPrint('Full-res image failed: $error');
        if (mounted) setState(() => _fullFailed = true);
      },
    );

    _stream = widget.fullProvider.resolve(
      createLocalImageConfiguration(context),
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If full-res failed, just show the thumbnail — don't crossfade to black
    final showFull = _fullLoaded && !_fullFailed;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail underneath as a safety net, dropped once it can no longer
        // be seen through the full-res frame.
        if (!(showFull && _fullOpaque))
          Image(
            image: widget.thumbProvider,
            fit: BoxFit.cover,
            alignment: widget.alignment,
            filterQuality: FilterQuality.medium,
          ),
        // Full-res fades in on top once loaded
        AnimatedOpacity(
          opacity: showFull ? 1.0 : 0.0,
          duration: Duration(milliseconds: _fullOpaque ? 0 : 200),
          onEnd: () {
            if (mounted && showFull && !_fullOpaque) {
              setState(() => _fullOpaque = true);
            }
          },
          child: showFull
              ? Image(
                  image: widget.fullProvider,
                  fit: BoxFit.cover,
                  alignment: widget.alignment,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
