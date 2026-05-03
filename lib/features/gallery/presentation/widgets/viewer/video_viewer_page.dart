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
    required this.showControls,
    required this.onTap,
    required this.onAutoHide,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
  });

  final String tag;
  final AssetEntity? asset;
  final VideoPlayerController? controller;
  final bool initialized;
  final bool showControls;
  final VoidCallback onTap;
  final VoidCallback onAutoHide;
  final VoidCallback onSliderDragStart;
  final VoidCallback onSliderDragEnd;

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage>
    with AutomaticKeepAliveClientMixin {
  bool _muted = false;
  Timer? _hideTimer;

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (widget.controller?.value.isPlaying ?? false)) {
        widget.onAutoHide();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.showControls) _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant VideoViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showControls && !oldWidget.showControls) {
      _scheduleHide();
    } else if (!widget.showControls) {
      _hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    final c = widget.controller;
    if (c == null) return;

    HapticFeedback.lightImpact();

    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel();
    } else {
      c.play();
      _scheduleHide();
    }
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _muted = !_muted);
    widget.controller?.setVolume(_muted ? 0 : 1);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    final c = widget.controller!;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Mirror ImageViewerPage layout (Align → AspectRatio → Hero)
          // so the Hero rect tween matches the image dismiss animation —
          // smooth shrink back to the gallery grid thumbnail.
          Align(
            alignment: Alignment.center,
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: Hero(
                tag: widget.tag,
                flightShuttleBuilder:
                    (
                      BuildContext flightContext,
                      Animation<double> animation,
                      HeroFlightDirection flightDirection,
                      BuildContext fromHeroContext,
                      BuildContext toHeroContext,
                    ) {
                      if (widget.asset == null) {
                        return const SizedBox.shrink();
                      }
                      return Material(
                        color: Colors.transparent,
                        child: Image(
                          image: AssetEntityImageProvider(
                            widget.asset!,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize(800, 800),
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      );
                    },
                child: VideoPlayer(c),
              ),
            ),
          ),

          // Center play button — Apple Photos shows it only when paused.
          ValueListenableBuilder(
            valueListenable: c,
            builder: (context, value, child) {
              final visible = widget.showControls && !value.isPlaying;
              return IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedScale(
                    scale: visible ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Center(
                      child: _GlassCircleButton(
                        size: 72,
                        onTap: _togglePlay,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom controls — floating glass pill (Apple-style).
          // Pushed up above the parent viewer's bottom action row so the two
          // bars don't overlap.
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 64,
            child: AnimatedSlide(
              offset: widget.showControls ? Offset.zero : const Offset(0, 0.35),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: widget.showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: !widget.showControls,
                  child: ValueListenableBuilder(
                    valueListenable: c,
                    builder: (context, value, child) {
                      return _GlassPill(
                        child: _VideoControls(
                          controller: c,
                          isPlaying: value.isPlaying,
                          muted: _muted,
                          onTogglePlay: _togglePlay,
                          onToggleMute: _toggleMute,
                          onSeeking: _scheduleHide,
                          onSliderDragStart: widget.onSliderDragStart,
                          onSliderDragEnd: widget.onSliderDragEnd,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass containers ─────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.size,
    required this.onTap,
    required this.child,
  });

  final double size;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ── Video controls ───────────────────────────────────────────────────────────

class _VideoControls extends StatefulWidget {
  const _VideoControls({
    required this.controller,
    required this.isPlaying,
    required this.muted,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onSeeking,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
  });

  final VideoPlayerController controller;
  final bool isPlaying;
  final bool muted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onSeeking;
  final VoidCallback onSliderDragStart;
  final VoidCallback onSliderDragEnd;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _scrubbing = false;

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).abs();
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final pos = value.position;
    final dur = value.duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final buffered = _bufferedFraction(value, dur);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        children: [
          _IconButton(
            icon: widget.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onTap: widget.onTogglePlay,
          ),
          const SizedBox(width: 2),
          _TimeLabel(text: _fmt(pos)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _AppleScrubber(
                progress: progress.toDouble(),
                buffered: buffered,
                scrubbing: _scrubbing,
                onChangeStart: (v) {
                  setState(() => _scrubbing = true);
                  HapticFeedback.selectionClick();
                  widget.onSliderDragStart();
                },
                onChanged: (v) {
                  widget.onSeeking();
                  if (dur.inMilliseconds > 0) {
                    widget.controller.seekTo(
                      Duration(milliseconds: (v * dur.inMilliseconds).round()),
                    );
                  }
                },
                onChangeEnd: (v) {
                  setState(() => _scrubbing = false);
                  widget.onSliderDragEnd();
                },
              ),
            ),
          ),
          _TimeLabel(text: '-${_fmt(dur - pos)}', muted: true),
          const SizedBox(width: 4),
          _IconButton(
            icon: widget.muted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            onTap: widget.onToggleMute,
          ),
        ],
      ),
    );
  }

  double _bufferedFraction(VideoPlayerValue value, Duration dur) {
    if (dur.inMilliseconds <= 0 || value.buffered.isEmpty) return 0;
    final end = value.buffered.last.end;
    return (end.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: muted ? 0.55 : 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Apple-style scrubber ─────────────────────────────────────────────────────
//
// Idle: a hairline track (no thumb), like Apple Photos.
// On press/drag: track expands, a small capsule thumb appears.

class _AppleScrubber extends StatefulWidget {
  const _AppleScrubber({
    required this.progress,
    required this.buffered,
    required this.scrubbing,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double progress;
  final double buffered;
  final bool scrubbing;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_AppleScrubber> createState() => _AppleScrubberState();
}

class _AppleScrubberState extends State<_AppleScrubber> {
  double? _dragValue;

  double _valueFromDx(double dx, double width) =>
      (dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            final v = _valueFromDx(d.localPosition.dx, width);
            setState(() => _dragValue = v);
            widget.onChangeStart(v);
            widget.onChanged(v);
          },
          onHorizontalDragUpdate: (d) {
            final v = _valueFromDx(d.localPosition.dx, width);
            setState(() => _dragValue = v);
            widget.onChanged(v);
          },
          onHorizontalDragEnd: (_) {
            final v = _dragValue ?? widget.progress;
            setState(() => _dragValue = null);
            widget.onChangeEnd(v);
          },
          onHorizontalDragCancel: () {
            final v = _dragValue ?? widget.progress;
            setState(() => _dragValue = null);
            widget.onChangeEnd(v);
          },
          onTapDown: (d) {
            final v = _valueFromDx(d.localPosition.dx, width);
            setState(() => _dragValue = v);
            widget.onChangeStart(v);
            widget.onChanged(v);
          },
          onTapUp: (_) {
            final v = _dragValue ?? widget.progress;
            setState(() => _dragValue = null);
            widget.onChangeEnd(v);
          },
          onTapCancel: () {
            final v = _dragValue ?? widget.progress;
            setState(() => _dragValue = null);
            widget.onChangeEnd(v);
          },
          child: SizedBox(
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: widget.scrubbing ? 14 : 6,
                child: CustomPaint(
                  painter: _ScrubberPainter(
                    progress: value,
                    buffered: widget.buffered,
                    scrubbing: widget.scrubbing,
                  ),
                  size: Size(width, widget.scrubbing ? 14 : 6),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.progress,
    required this.buffered,
    required this.scrubbing,
  });

  final double progress;
  final double buffered;
  final bool scrubbing;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);

    // Inactive track
    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      inactivePaint,
    );

    // Buffered track (lighter, sits between inactive and active)
    if (buffered > 0) {
      final bufferedPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * buffered, size.height),
          radius,
        ),
        bufferedPaint,
      );
    }

    // Active track
    final activePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * progress, size.height),
        radius,
      ),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter old) =>
      old.progress != progress ||
      old.buffered != buffered ||
      old.scrubbing != scrubbing;
}
