import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../providers/gallery_notifier.dart';

// Single source of truth — both precache and display must use the same key
const kDisplaySize = ThumbnailSize(1920, 1920);

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
      _animation = Matrix4Tween(
        begin: matrix,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
    } else {
      // Zoom in at tap position
      final position = _doubleTapPosition ?? Offset.zero;
      final Matrix4 zoomedMatrix = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);

      _animation = Matrix4Tween(
        begin: matrix,
        end: zoomedMatrix,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
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

    return Hero(
      tag: widget.heroTag ?? widget.photo.path,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1.0,
          maxScale: 4.0,
          panEnabled: _isZoomed,
          child: Image(
            image: AssetEntityImageProvider(
              widget.photo.assetEntity!,
              isOriginal: false,
              thumbnailSize: kDisplaySize,
            ),
            fit: BoxFit.contain,
            alignment: widget.alignment,
            width: double.infinity,
            height: double.infinity,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: AssetEntityImageProvider(
                      widget.photo.assetEntity!,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize(400, 400),
                    ),
                    fit: BoxFit.contain,
                    alignment: widget.alignment,
                  ),
                  child,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
