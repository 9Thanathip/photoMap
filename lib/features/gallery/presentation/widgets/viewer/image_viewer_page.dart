import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/widgets/main_gallery/photo_tile.dart';
import '../../providers/gallery_notifier.dart';

// Display size for the full viewer image
const kDisplaySize = ThumbnailSize(1920, 1920);
// Thumbnail size matching the gallery grid — used for Hero flight
const kThumbSize = ThumbnailSize.square(200);

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

class _ImageViewerPageState extends State<ImageViewerPage>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  bool _isZoomed = false;
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
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      _isZoomed = zoomed;
      widget.onZoomChanged(zoomed);
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
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);

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
        child: Icon(Icons.broken_image, color: Colors.white, size: 64),
      );
    }

    final asset = widget.photo.assetEntity!;

    // Lightweight thumbnail provider (same as gallery grid) — already decoded & cached
    final thumbProvider = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: kThumbSize,
    );

    // Full-resolution provider — may take time to decode for large photos
    final fullProvider = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: kDisplaySize,
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
          child: Hero(
            tag: widget.heroTag ?? widget.photo.path,
            // Use the small thumbnail during Hero flight for smooth animation
            flightShuttleBuilder: (_, animation, direction, fromCtx, toCtx) {
              return Material(
                color: Colors.transparent,
                child: Image(
                  image: thumbProvider,
                  fit: BoxFit.contain,
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
  ImageStreamListener? _listener;
  ImageStream? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveFullImage();
  }

  void _resolveFullImage() {
    // Clean up previous listener
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }

    _listener = ImageStreamListener(
      (info, synchronousCall) {
        if (mounted && !_fullLoaded) {
          setState(() => _fullLoaded = true);
        }
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
        // Thumbnail always rendered underneath as safety net
        Image(
          image: widget.thumbProvider,
          fit: BoxFit.contain,
          alignment: widget.alignment,
        ),
        // Full-res fades in on top once loaded
        AnimatedOpacity(
          opacity: showFull ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: showFull
              ? Image(
                  image: widget.fullProvider,
                  fit: BoxFit.contain,
                  alignment: widget.alignment,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
