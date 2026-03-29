import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/gallery_notifier.dart';
import 'photo_editor_sheet.dart';

// Single source of truth — both precache and display must use the same key
// so the preloaded image is actually served from cache when the page appears.
const _kDisplaySize = ThumbnailSize(1920, 1920);

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

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  bool _isZoomed = false;
  bool _dragging = false;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // Spring controller: value = current Y offset in pixels
  late final AnimationController _spring;

  double get _dy => _spring.value;

  // Raw pointer tracking (avoids gesture arena so PageView stays smooth)
  int? _trackPointer;
  double _dragStartX = 0, _dragStartY = 0;
  bool _vertActive = false;
  VelocityTracker? _vt;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Hold more decoded images so slides after the 3rd don't re-decode
    PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20; // 256 MB
    _initVideo(_currentIndex);
    // Preload adjacent after first frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _precacheAdjacent(_currentIndex));

    _spring = AnimationController(
      vsync: this,
      lowerBound: -3000,
      upperBound: 3000,
      value: 0,
      // No listener — AnimatedBuilder drives repaints without setState
    );
  }

  @override
  void dispose() {
    _spring.dispose();
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

  void _precacheAdjacent(int index) {
    for (final i in [index - 1, index + 1, index + 2]) {
      if (i < 0 || i >= widget.photos.length) continue;
      final asset = widget.photos[i].assetEntity;
      if (asset == null || asset.type == AssetType.video) continue;
      precacheImage(
        AssetEntityImageProvider(asset,
            isOriginal: false, thumbnailSize: _kDisplaySize),
        context,
      );
    }
  }

  void _toggleOverlay() {
    if (_dragging) return;
    setState(() => _showOverlay = !_showOverlay);
  }

  void _onZoomChanged(bool zoomed) {
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_isZoomed) return;
    _trackPointer = e.pointer;
    _dragStartX = e.localPosition.dx;
    _dragStartY = e.localPosition.dy;
    _vertActive = false;
    _vt = VelocityTracker.withKind(e.kind);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_isZoomed || e.pointer != _trackPointer) return;
    _vt?.addPosition(e.timeStamp, e.localPosition);

    final dx = e.localPosition.dx - _dragStartX;
    final dy = e.localPosition.dy - _dragStartY;

    if (!_vertActive) {
      if (dx.abs() + dy.abs() < 8) return; // wait for enough movement
      // Only activate for clearly downward, more vertical than horizontal
      if (dy > 0 && dy > dx.abs() * 1.5) {
        _vertActive = true;
        setState(() => _dragging = true);
      } else {
        _trackPointer = null; // yield to PageView
        return;
      }
    }

    _spring.stop();
    _spring.value = dy.clamp(0.0, 3000.0);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _trackPointer || !_vertActive) return;
    _vertActive = false;
    _trackPointer = null;
    setState(() => _dragging = false);

    final screenH = MediaQuery.sizeOf(context).height;
    final vel = _vt?.getVelocity().pixelsPerSecond.dy ?? 0;

    if (vel > 700 || _dy > screenH * 0.2) {
      final targetY = screenH * 1.3;
      final speed = vel.clamp(800.0, 4000.0);
      final ms = ((targetY - _dy) / speed * 1000).clamp(100.0, 280.0);
      _spring
          .animateTo(targetY,
              duration: Duration(milliseconds: ms.round()),
              curve: Curves.easeIn)
          .then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _spring.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 600, damping: 38),
        _dy, 0, vel,
      ));
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _trackPointer) return;
    _vertActive = false;
    _trackPointer = null;
    setState(() => _dragging = false);
    if (_dy != 0) {
      _spring.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 600, damping: 38),
        _dy, 0, 0,
      ));
    }
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
    final screenH = MediaQuery.sizeOf(context).height;

    // PageView is built once and reused — AnimatedBuilder won't rebuild it
    final pageView = PageView.builder(
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
        _precacheAdjacent(index);
      },
      itemBuilder: (_, index) {
        final photo = widget.photos[index];
        final page = photo.assetEntity?.type == AssetType.video
            ? _VideoPage(
                controller: index == _currentIndex ? _videoController : null,
                initialized: index == _currentIndex && _videoInitialized,
                onTap: _toggleOverlay,
              )
            : _ImagePage(
                photo: photo,
                onZoomChanged: _onZoomChanged,
                onTap: _toggleOverlay,
              );
        // Horizontal padding creates a black gap between pages when sliding
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: page,
        );
      },
    );

    final overlay = _buildOverlay();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _spring,
        builder: (context, child) {
          final dy = _spring.value;
          final progress = (dy / (screenH * 0.45)).clamp(0.0, 1.0);
          final bgOpacity = (1.0 - progress * 0.9).clamp(0.0, 1.0);
          final scale = 1.0 - progress * 0.07;
          final overlayOpacity = _showOverlay
              ? (1.0 - progress * 2.5).clamp(0.0, 1.0)
              : 0.0;

          return ColoredBox(
            color: Colors.black.withValues(alpha: bgOpacity),
            child: Stack(
              children: [
                // ── Photo layer — only Transform rebuilds, PageView is reused ──
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                ),
                // ── Overlay — fixed position, fades with drag ─────────────────
                IgnorePointer(
                  ignoring: !_showOverlay || _dragging,
                  child: Opacity(opacity: overlayOpacity, child: overlay),
                ),
              ],
            ),
          );
        },
        child: pageView, // passed as child → not rebuilt by AnimatedBuilder
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
        child: SizedBox.expand(
          child: widget.photo.assetEntity != null
              ? Image(
                  image: AssetEntityImageProvider(
                    widget.photo.assetEntity!,
                    isOriginal: false,
                    thumbnailSize: _kDisplaySize,
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
