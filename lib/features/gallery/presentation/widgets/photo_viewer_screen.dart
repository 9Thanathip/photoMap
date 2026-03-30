import 'dart:async';
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
import 'image_viewer_page.dart';
import 'video_viewer_page.dart';

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
  bool _isSliderDragging = false;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // Spring controller: value = current Y offset in pixels
  late final AnimationController _spring;

  double get _dy => _spring.value;

  // Gesture tracking

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
            isOriginal: false, thumbnailSize: kDisplaySize),
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

    if (vel.abs() > 700 || _dy.abs() > screenH * 0.2) {
      // Let the Hero transition handle the beautiful return flight back into the grid!
      if (mounted) Navigator.of(context).pop();
    } else {
      _spring.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 600, damping: 38),
        _dy, 0, vel,
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
      physics: _isZoomed || _isSliderDragging
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
            ? VideoViewerPage(
                tag: photo.path,
                controller: index == _currentIndex ? _videoController : null,
                initialized: index == _currentIndex && _videoInitialized,
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
          final progress = (dy.abs() / (screenH * 0.45)).clamp(0.0, 1.0);
          final bgOpacity = (1.0 - progress).clamp(0.0, 1.0);
          final scale = 1.0 - progress * 0.25; // Smooth squish when dragged
          // Drag-based fade only — tap-based toggle is handled by AnimatedOpacity below
          final overlayOpacity = (1.0 - progress * 3.0).clamp(0.0, 1.0);

          return ColoredBox(
            color: Colors.black.withValues(alpha: bgOpacity),
            child: Stack(
              children: [
                // ── Photo layer — only Transform rebuilds, PageView is reused ──
                GestureDetector(
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                ),
                // ── Overlay — tap toggles via AnimatedOpacity, drag fades via Opacity ──
                IgnorePointer(
                  ignoring: !_showOverlay || _dragging,
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
