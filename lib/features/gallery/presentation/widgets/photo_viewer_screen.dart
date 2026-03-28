import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/gallery_notifier.dart';
import 'photo_editor_sheet.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<PhotoItem> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  bool _isZoomed = false;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  PhotoItem get _current => widget.photos[_currentIndex];
  bool get _isVideo => _current.assetEntity?.type == AssetType.video;

  Future<void> _initVideo(int index) async {
    _videoController?.dispose();
    if (!mounted) return;
    setState(() {
      _videoController = null;
      _videoInitialized = false;
    });

    final photo = widget.photos[index];
    if (photo.assetEntity?.type != AssetType.video) return;

    final File? file = await photo.assetEntity!.file;
    if (file == null || !mounted) return;

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }

    controller.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _videoController = controller;
      _videoInitialized = true;
    });
    controller.play();
  }

  void _toggleOverlay() => setState(() => _showOverlay = !_showOverlay);

  void _onZoomChanged(bool zoomed) {
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _openEditor() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoEditorSheet(
        photo: _current,
        heroTag: 'viewer_$_currentIndex',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _isZoomed = false;
              });
              _initVideo(index);
            },
            itemBuilder: (_, index) {
              final photo = widget.photos[index];
              if (photo.assetEntity?.type == AssetType.video) {
                return _VideoPage(
                  controller: index == _currentIndex ? _videoController : null,
                  initialized: index == _currentIndex && _videoInitialized,
                  onTap: _toggleOverlay,
                );
              }
              return _ImagePage(
                photo: photo,
                onZoomChanged: _onZoomChanged,
                onTap: _toggleOverlay,
              );
            },
          ),
          IgnorePointer(
            ignoring: !_showOverlay,
            child: AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildOverlay(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        // Top bar
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  '${_currentIndex + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Bottom bar
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isVideo && _videoInitialized && _videoController != null)
                  _VideoControls(controller: _videoController!),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_isVideo)
                        FilledButton.tonal(
                          onPressed: _openEditor,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(50),
                            foregroundColor: Colors.white,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Edit'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Image page ────────────────────────────────────────────────────────────────

class _ImagePage extends StatefulWidget {
  const _ImagePage({
    required this.photo,
    required this.onZoomChanged,
    required this.onTap,
  });

  final PhotoItem photo;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
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
        child: Center(
          child: widget.photo.assetEntity != null
              ? Image(
                  image: AssetEntityImageProvider(
                    widget.photo.assetEntity!,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize(1920, 1920),
                  ),
                  fit: BoxFit.contain,
                )
              : const Icon(Icons.broken_image, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}

// ── Video page ────────────────────────────────────────────────────────────────

class _VideoPage extends StatelessWidget {
  const _VideoPage({
    this.controller,
    required this.initialized,
    required this.onTap,
  });

  final VideoPlayerController? controller;
  final bool initialized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!initialized || controller == null) {
      return GestureDetector(
        onTap: onTap,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: VideoPlayer(controller!),
        ),
      ),
    );
  }
}

// ── Video controls ────────────────────────────────────────────────────────────

class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 2,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white38,
            thumbColor: Colors.white,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: progress.toDouble(),
            onChanged: (v) => controller.seekTo(
              Duration(milliseconds: (v * duration.inMilliseconds).round()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                child: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_fmt(position)} / ${_fmt(duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
