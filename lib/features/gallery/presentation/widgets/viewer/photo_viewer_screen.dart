import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/gallery_notifier.dart';
import '../editor/photo_editor_screen.dart';
import 'image_viewer_page.dart';
import 'video_viewer_page.dart';
import 'photo_info_content.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    this.routeAnimation,
  });

  final List<PhotoItem> photos;
  final int initialIndex;
  final Animation<double>? routeAnimation;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late int _currentIndex;
  late List<PhotoItem> _photos; // Mutable copy for deletion support
  bool _showOverlay = true;
  bool _isZoomed = false;
  bool _dragging = false;
  bool _isSliderDragging = false;
  bool _isDeleting = false;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // Spring controller: value = current Y offset in pixels
  late final AnimationController _spring;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20;
    _initVideo(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _precacheAdjacent(_currentIndex),
    );

    _spring = AnimationController(
      vsync: this,
      lowerBound: -3000,
      upperBound: 3000,
      value: 0,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spring.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          // Force a rebuild to re-trigger image loading and route visibility
        });
        // Re-play video if it was playing
        if (_isVideo && _videoInitialized && _videoController != null) {
          _videoController!.play();
        }
      }
    }
  }

  PhotoItem get _current => _photos[_currentIndex];
  bool get _isVideo => _current.assetEntity?.type == AssetType.video;

  Future<void> _initVideo(int index) async {
    _videoController?.dispose();
    if (!mounted) return;
    setState(() {
      _videoController = null;
      _videoInitialized = false;
    });

    final photo = _photos[index];
    if (photo.assetEntity?.type != AssetType.video) return;

    final File? file = await photo.assetEntity!.file;
    if (file == null || !mounted) return;

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _videoInitialized = true;
    });
    controller.play();
  }

  void _precacheAdjacent(int index) {
    for (final i in [index - 1, index + 1, index + 2]) {
      if (i < 0 || i >= _photos.length) continue;
      final asset = _photos[i].assetEntity;
      if (asset == null || asset.type == AssetType.video) continue;
      precacheImage(
        AssetEntityImageProvider(
          asset,
          isOriginal: false,
          thumbnailSize: kDisplaySize,
        ),
        context,
      );
    }
  }

  void _toggleOverlay() {
    if (_dragging) return;
    if (_spring.value < -50) {
      // If info panel is open, tap on image closes it
      _spring.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _showOverlay = !_showOverlay);
  }

  void _onZoomChanged(bool zoomed) {
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _onVerticalDragStart(DragStartDetails e) {
    if (_isZoomed) return;
    setState(() => _dragging = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails e) {
    if (_isZoomed) return;
    _spring.stop();
    // Use delta to prevent the initial "jump" caused by gesture slop.
    _spring.value = (_spring.value + e.delta.dy).clamp(-3000.0, 3000.0);
  }

  void _onVerticalDragEnd(DragEndDetails e) {
    if (_isZoomed) return;
    setState(() => _dragging = false);

    final screenH = MediaQuery.sizeOf(context).height;
    final vel = e.primaryVelocity ?? 0;
    final dy = _spring.value;

    if (dy < -50) {
      // Info panel is open (or being opened)
      if (vel > 500 || dy > -250) {
        // Swipe down to close info panel (return to normal view)
        _snapTo(0, vel);
      } else {
        // Keep info panel open
        _snapTo(-520, vel);
      }
    } else {
      // Info panel is closed
      if (dy > 0) {
        // Dragging down (Dismissal behavior)
        if (vel > 700 || dy > screenH * 0.15) {
          // If swipe-down is fast or far enough, close the whole viewer
          if (mounted) Navigator.of(context).pop();
        } else {
          // Otherwise, snap back to center
          _snapTo(0, vel);
        }
      } else {
        // Dragging up (Opening info panel)
        if (vel < -200 || dy < -40) {
          _snapTo(-520, vel);
        } else {
          _snapTo(0, vel);
        }
      }
    }
  }

  void _snapTo(double target, double velocity) {
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 200, damping: 24),
      _spring.value,
      target,
      velocity,
    );
    _spring.animateWith(simulation);
  }

  Future<void> _deleteCurrentPhoto() async {
    if (_isDeleting || _photos.isEmpty) return;
    _isDeleting = true;

    final photo = _current;
    final photoPath = photo.path;

    try {
      // iOS shows system confirmation dialog via deleteWithIds
      final deleted = await PhotoManager.editor.deleteWithIds([photoPath]);

      if (!mounted || deleted.isEmpty) {
        _isDeleting = false;
        return;
      }

      // Update gallery state (already deleted from device above)
      final container = ProviderScope.containerOf(context);
      container.read(galleryStateProvider.notifier).removeFromState(photoPath);

      final wasLast = _photos.length == 1;
      final wasAtEnd = _currentIndex == _photos.length - 1;

      if (wasLast) {
        // Last photo deleted — close viewer
        Navigator.of(context).pop();
        return;
      }

      HapticFeedback.mediumImpact();

      setState(() {
        _photos.removeAt(_currentIndex);
        if (wasAtEnd) {
          _currentIndex = _photos.length - 1;
        }
        // Recreate page controller to reflect new list
        _pageController.dispose();
        _pageController = PageController(initialPage: _currentIndex);
      });

      _spring.value = 0;
      _initVideo(_currentIndex);
    } finally {
      _isDeleting = false;
    }
  }

  void _openEditor() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        opaque: false, // Allows cross-fade beautifully
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: PhotoEditorScreen(photo: _current, heroTag: _current.path),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;

    // PageView is built once and reused — AnimatedBuilder won't rebuild it
    final pageView = PageView.builder(
      key: const PageStorageKey('photo_viewer_pageview'),
      controller: _pageController,
      physics: _isZoomed || _isSliderDragging
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: _photos.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _isZoomed = false;
        });
        // Reset scroll position on page change
        _spring.value = 0;
        _initVideo(index);
        _precacheAdjacent(index);
      },
      itemBuilder: (_, index) {
        final photo = _photos[index];
        final isCurrent = index == _currentIndex;
        final heroTag = isCurrent
            ? photo.path
            : '__no_hero_${index}_${photo.path}';

        final page = photo.assetEntity?.type == AssetType.video
            ? VideoViewerPage(
                tag: heroTag,
                asset: photo.assetEntity,
                controller: isCurrent ? _videoController : null,
                initialized: isCurrent && _videoInitialized,
                onTap: _toggleOverlay,
                onSliderDragStart: () =>
                    setState(() => _isSliderDragging = true),
                onSliderDragEnd: () =>
                    setState(() => _isSliderDragging = false),
              )
            : ImageViewerPage(
                photo: photo,
                onZoomChanged: _onZoomChanged,
                onTap: _toggleOverlay,
                heroTag: heroTag,
              );

        if (!isCurrent) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: RepaintBoundary(child: page),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _spring,
            builder: (context, child) {
              final dy = _spring.value;
              final screenH = MediaQuery.sizeOf(context).height;

              // Smoothly interpolate alignment from center (0,0) to bottom (0,1)
              // as the info panel opens (dy from 0 to -520)
              final alignmentT = (dy / -520.0).clamp(0.0, 1.0);
              final alignment = Alignment(0, alignmentT);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        RepaintBoundary(
                          child: photo.assetEntity?.type == AssetType.video
                              ? page
                              : ImageViewerPage(
                                  photo: photo,
                                  onZoomChanged: _onZoomChanged,
                                  onTap: _toggleOverlay,
                                  alignment: alignment,
                                ),
                        ),
                        Positioned(
                          top: screenH,
                          left: 0,
                          right: 0,
                          child: PhotoInfoContent(photo: photo),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            child: page,
          ),
        );
      },
    );

    final overlay = _buildOverlay();
    final photoPath = _photos.isNotEmpty ? _current.path : 'empty';

    return Scaffold(
      key: ValueKey('viewer_$photoPath'),
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: widget.routeAnimation != null
            ? Listenable.merge([_spring, widget.routeAnimation!])
            : _spring,
        builder: (context, child) {
          final dy = _spring.value;
          final screenH = MediaQuery.sizeOf(context).height;
          
          // Real Fix: Ensure routeAlpha is 1.0 after transition completes, 
          // avoiding the "disappearing on resume" bug on iOS.
          final routeAlpha = widget.routeAnimation?.isCompleted == true 
              ? 1.0 
              : (widget.routeAnimation?.value ?? 1.0);

          // Dismissal progress (0 to 1) only when dragging down
          final dismissProgress = dy > 0
              ? (dy / (screenH * 0.4)).clamp(0.0, 1.0)
              : 0.0;

          // Smooth scale and opacity tracking
          final scale = 1.0 - (dismissProgress * 0.18);
          final bgOpacity = ((1.0 - dismissProgress) * routeAlpha).clamp(
            0.0,
            1.0,
          );

          // Fade UI buttons as we drag away
          final overlayOpacity = ((1.0 - (dy.abs() / 150.0)) * routeAlpha)
              .clamp(0.0, 1.0);

          return ColoredBox(
            color: Colors.black.withOpacity(routeAlpha),
            child: Stack(
              children: [
                GestureDetector(
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: child, // This is the PageView
                ),
                // ── Overlay ──
                IgnorePointer(
                  ignoring: !_showOverlay || _dragging || dy < -20,
                  child: AnimatedOpacity(
                    opacity: _showOverlay ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Opacity(opacity: overlayOpacity, child: overlay),
                  ),
                ),
              ],
            ),
          );
        },
        child: pageView,
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
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  '${_currentIndex + 1} / ${_photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Bottom bar - Apple Style
        IgnorePointer(
          ignoring: !_showOverlay || _dragging,
          child: AnimatedOpacity(
            opacity: _showOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.4, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bottomAction(Icons.ios_share, () {}),
                      _bottomAction(Icons.favorite_border_rounded, () {}),
                      _bottomAction(Icons.info_outline_rounded, () {
                        _snapTo(-520, 0);
                      }),
                      if (!_isVideo)
                        _bottomAction(Icons.tune_rounded, _openEditor),
                      _bottomAction(
                        Icons.delete_outline_rounded,
                        _deleteCurrentPhoto,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomAction(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 26),
      onPressed: onTap,
      splashRadius: 24,
    );
  }
}
