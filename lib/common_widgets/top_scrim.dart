import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_tokens.dart';

/// Scroll distance over which the top scrim reaches full strength.
const double kTopScrimRamp = 72.0;

/// Maps a scroll offset to scrim strength: 0 while resting at the top, 1 once
/// [kTopScrimRamp] pixels have gone by.
double topScrimProgress(double pixels) =>
    (pixels / kTopScrimRamp).clamp(0.0, 1.0);

/// Drives [scrim] from a `ScrollNotification`. Horizontal scrollers are
/// ignored — a `TabBarView`'s page offset reports through the same listener and
/// would otherwise paint a full-strength scrim mid-swipe. Always returns false
/// so the notification keeps bubbling.
bool updateTopScrim(ValueNotifier<double> scrim, ScrollNotification n) {
  if (n.metrics.axis == Axis.vertical) {
    scrim.value = topScrimProgress(n.metrics.pixels);
  }
  return false;
}

/// Foreground colour for bare (non-glass) content drawn on top of a [TopScrim].
/// In dark theme the scrim is surface-tinted, so the colour never moves; in
/// light theme it darkens to black, so the type crosses over to white with it.
Color topScrimForeground(BuildContext context, double progress) {
  final onSurface = Theme.of(context).colorScheme.onSurface;
  if (context.isDark) return onSurface;
  return Color.lerp(onSurface, Colors.white, progress)!;
}

/// Top-of-screen readability scrim for the photo galleries: nothing at rest,
/// fading in with the scroll offset. Black in light theme, surface-tinted in
/// dark. Place it in a `Stack` under the header, sized by [height].
class TopScrim extends StatelessWidget {
  const TopScrim({
    super.key,
    required this.progress,
    required this.height,
  });

  final ValueListenable<double> progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, t, _) {
            if (t == 0) return const SizedBox.shrink();
            final dark = context.isDark;
            final base = dark ? context.tokens.surfaceBase : Colors.black;
            final top = dark ? 0.95 : 0.62;
            final mid = dark ? 0.60 : 0.30;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    base.withValues(alpha: top * t),
                    base.withValues(alpha: mid * t),
                    base.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
