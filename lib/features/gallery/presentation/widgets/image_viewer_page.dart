import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_notifier.dart';

// Single source of truth — both precache and display must use the same key
const kDisplaySize = ThumbnailSize(1920, 1920);

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.photo,
    required this.onZoomChanged,
    required this.onTap,
  });

  final PhotoItem photo;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final _controller = TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _isZoomed,
        child: SizedBox.expand(
          child: widget.photo.assetEntity != null
              ? Image(
                  image: AssetEntityImageProvider(
                    widget.photo.assetEntity!,
                    isOriginal: false,
                    thumbnailSize: kDisplaySize,
                  ),
                  fit: BoxFit.contain,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) return child;
                    // Low-res placeholder while 1920px thumbnail decodes
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
                        ),
                        child,
                      ],
                    );
                  },
                )
              : const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
        ),
      ),
    );
  }
}
