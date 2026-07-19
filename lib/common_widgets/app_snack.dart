import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_tokens.dart';

/// Kind of status message — drives the leading icon + accent colour.
enum AppSnackType { success, error, info }

/// App-wide status toast. Slides in from the **top** (so it never hides the
/// bottom navigation bar) and auto-dismisses. Overlay-based, so it works from
/// any context — screens, sheets, dialogs.
///
/// Usage: `AppSnack.success(context, l10n.frameSaved);`
class AppSnack {
  const AppSnack._();

  static OverlayEntry? _current;

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppSnackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppSnackType.error);

  static void info(BuildContext context, String message) =>
      show(context, message, type: AppSnackType.info);

  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.success,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    showOnOverlay(overlay, message, type: type);
  }

  /// Same as [show] but from a pre-resolved [OverlayState]. Capture the overlay
  /// (`Overlay.of(context, rootOverlay: true)`) BEFORE an `await` so a toast can
  /// still be shown after the originating screen has been popped.
  static void showOnOverlay(
    OverlayState overlay,
    String message, {
    AppSnackType type = AppSnackType.success,
  }) {
    // Replace any visible toast so they never stack.
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppSnackView(
        message: message,
        type: type,
        onDismissed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _AppSnackView extends StatefulWidget {
  const _AppSnackView({
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  final String message;
  final AppSnackType type;
  final VoidCallback onDismissed;

  @override
  State<_AppSnackView> createState() => _AppSnackViewState();
}

class _AppSnackViewState extends State<_AppSnackView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  static const _visibleFor = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(_visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _c.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({IconData icon, Color accent}) _style(AppTokens t) => switch (widget.type) {
        AppSnackType.success => (
            icon: Icons.check_circle_rounded,
            accent: const Color(0xFF2FBF71),
          ),
        AppSnackType.error => (icon: Icons.error_rounded, accent: t.accentCoral),
        AppSnackType.info => (
            icon: Icons.info_rounded,
            accent: t.textSecondary,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final topPad = MediaQuery.paddingOf(context).top;
    final s = _style(t);

    return Positioned(
      top: topPad + 10,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.2),
            end: Offset.zero,
          ).animate(_anim),
          child: FadeTransition(
            opacity: _anim,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.45 : 0.14,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 20, color: s.accent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
