import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';

class VideoViewerPage extends StatefulWidget {
  const VideoViewerPage({
    super.key,
    required this.tag,
    this.controller,
    this.asset,
    required this.initialized,
    required this.onTap,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
  });

  final String tag;
  final AssetEntity? asset;
  final VideoPlayerController? controller;
  final bool initialized;
  final VoidCallback onTap;
  final VoidCallback onSliderDragStart;
  final VoidCallback onSliderDragEnd;

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  bool _showControls = true;
  bool _muted = false;
  Timer? _hideTimer;

  // No longer needed: _onController and setState.
  // We use ValueListenableBuilder instead for snappier updates.

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (widget.controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHide();
    }
    widget.onTap();
  }

  void _togglePlay() {
    final c = widget.controller;
    if (c == null) return;
    
    HapticFeedback.lightImpact();
    
    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      c.play();
      _scheduleHide();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    widget.controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.initialized || widget.controller == null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.asset != null)
              Hero(
                tag: widget.tag,
                child: Image(
                  image: AssetEntityImageProvider(
                    widget.asset!,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize(800, 800),
                  ),
                  fit: BoxFit.contain,
                ),
              )
            else
              const ColoredBox(color: Colors.black),
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final c = widget.controller!;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video - Don't rebuild this on every frame
          Center(
            child: Hero(
              tag: widget.tag,
              flightShuttleBuilder: (
                BuildContext flightContext,
                Animation<double> animation,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                return Material(
                  color: Colors.transparent,
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                );
              },
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            ),
          ),

          // Center Play/Pause Overlay - Optimized with ValueListenableBuilder
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: c,
                  builder: (context, value, child) {
                    return GestureDetector(
                      onTapDown: (_) => _togglePlay(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Bottom Controls - Optimized with ValueListenableBuilder
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: ValueListenableBuilder(
                  valueListenable: c,
                  builder: (context, value, child) {
                    return _VideoControls(
                      controller: c,
                      muted: _muted,
                      onToggleMute: _toggleMute,
                      onSeeking: _scheduleHide,
                      onSliderDragStart: widget.onSliderDragStart,
                      onSliderDragEnd: widget.onSliderDragEnd,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video controls ────────────────────────────────────────────────────────────

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.muted,
    required this.onToggleMute,
    required this.onSeeking,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onSeeking;
  final VoidCallback onSliderDragStart;
  final VoidCallback onSliderDragEnd;

  static String _fmt(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:'
          '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
          '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pos = controller.value.position;
    final dur = controller.value.duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time Labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "-${_fmt(dur - pos)}", // Remaining time
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            
            // Minimal Scrubber
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                trackShape: const _CustomTrackShape(),
              ),
              child: Slider(
                value: progress.toDouble(),
                onChangeStart: (_) => onSliderDragStart(),
                onChangeEnd: (_) => onSliderDragEnd(),
                onChanged: (v) {
                  onSeeking();
                  controller.seekTo(Duration(
                      milliseconds: (v * dur.inMilliseconds).round()));
                },
              ),
            ),

            // Additional bottom row (Mute, etc.)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggleMute();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A more minimal track shape that doesn't have the default padding
class _CustomTrackShape extends RoundedRectSliderTrackShape {
  const _CustomTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx + 20;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - 40;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
