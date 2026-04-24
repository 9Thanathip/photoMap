import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' hide LatLng;
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/gallery_notifier.dart';
import 'photo_editor_screen.dart';
import 'image_viewer_page.dart';
import 'video_viewer_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';



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
    if (_spring.value < -50) {
      // If info panel is open, tap on image closes it
      _spring.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
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

    if (dy < -30) {
      // Info panel is open (or being opened)
      if (vel > 300 || dy > -200) {
        // Swipe down to close info panel (return to normal view)
        _snapTo(0, vel);
      } else {
        // Keep info panel open
        _snapTo(-420, vel);
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
        if (vel < -300 || dy < -60) {
          _snapTo(-420, vel);
        } else {
          _snapTo(0, vel);
        }
      }
    }
  }

  void _snapTo(double target, double velocity) {
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1,
        stiffness: 200,
        damping: 24,
      ),
      _spring.value,
      target,
      velocity,
    );
    _spring.animateWith(simulation);
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
            child: PhotoEditorScreen(
              photo: _current,
              heroTag: _current.path,
            ),
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
      controller: _pageController,
      physics: _isZoomed || _isSliderDragging
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: widget.photos.length,
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _spring,
            builder: (context, child) {
              final dy = _spring.value;
              final screenH = MediaQuery.sizeOf(context).height;
              
              // Smoothly interpolate alignment from center (0,0) to bottom (0,1) 
              // as the info panel opens (dy from 0 to -420)
              final alignmentT = (dy / -420.0).clamp(0.0, 1.0);
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
                          child: _PhotoInfoContent(photo: photo),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _spring,
        builder: (context, child) {
          final dy = _spring.value;
          final screenH = MediaQuery.sizeOf(context).height;
          
          // Dismissal progress (0 to 1) only when dragging down
          final dismissProgress = dy > 0 ? (dy / (screenH * 0.4)).clamp(0.0, 1.0) : 0.0;
          
          // Smooth scale and opacity tracking
          final scale = 1.0 - (dismissProgress * 0.18);
          final bgOpacity = (1.0 - dismissProgress).clamp(0.0, 1.0);
          
          // Fade UI buttons as we drag away
          final overlayOpacity = (1.0 - (dy.abs() / 150.0)).clamp(0.0, 1.0);

          return ColoredBox(
            color: dy <= 0 ? Colors.black : Colors.black.withOpacity(bgOpacity),
            child: Stack(
              children: [
                GestureDetector(
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: Transform.scale(
                    scale: scale,
                    child: child, // This is the PageView
                  ),
                ),
                // ── Overlay ──
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
                         _snapTo(-420, 0);
                      }),
                      if (!_isVideo)

                        _bottomAction(Icons.tune_rounded, _openEditor),
                      _bottomAction(Icons.delete_outline_rounded, () {}),
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

class _PhotoInfoContent extends StatelessWidget {
  const _PhotoInfoContent({required this.photo});
  final PhotoItem photo;

  String _getWeekday(int day) {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day - 1];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = date.day.toString();
    final month = months[date.month - 1];
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_getWeekday(date.weekday)} • $day $month $year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asset = photo.assetEntity;
    final mp = asset != null ? (asset.width * asset.height / 1000000).toStringAsFixed(1) : '0';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(photo.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (asset?.title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        asset!.title!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // Technical Info Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      asset?.type == AssetType.video ? Icons.videocam_rounded : Icons.camera_alt_rounded,
                      size: 20,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset?.type == AssetType.video ? 'Video Recording' : 'Apple iPhone 17 Pro',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            asset?.type == AssetType.video 
                                ? 'Main Camera — 4K 60fps' 
                                : 'Ultra Wide Camera — 13 mm f2.2',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        asset?.mimeType?.split('/').last.toUpperCase() ?? 'JPEG',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoDetail(asset?.type == AssetType.video ? 'Quality' : 'Resolution', 
                        asset?.type == AssetType.video ? '4K • 60 fps' : '$mp MP • ${asset?.width} × ${asset?.height}', isDark, flex: 2),
                    _infoDetail('ISO', '50', isDark),
                    _infoDetail('Exposure', '0 ev', isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Location Section
          if (photo.hasLocation) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFF1E1E1E),
                child: Stack(
                  children: [
                    // Real Flutter Map
                    Positioned.fill(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(photo.lat, photo.lng),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.photo_map.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(photo.lat, photo.lng),
                                width: 80,
                                height: 80,
                                child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Map Overlay like Apple
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    photo.district.isNotEmpty ? photo.district : photo.province,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [photo.province, photo.country].where((s) => s.isNotEmpty).join(', '),
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

        ],
      ),
    );
  }

  Widget _infoDetail(String label, String value, bool isDark, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

