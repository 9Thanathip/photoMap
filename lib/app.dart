import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'features/gallery/presentation/providers/gallery_notifier.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final gallery = ref.watch(galleryStateProvider);
    final auth = ref.watch(authNotifierProvider);

    return MaterialApp.router(
      title: 'Jaruek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return SetupOverlayWrapper(child: child);
      },
    );
  }
}

class SetupOverlayWrapper extends ConsumerStatefulWidget {
  final Widget? child;
  const SetupOverlayWrapper({super.key, this.child});

  @override
  ConsumerState<SetupOverlayWrapper> createState() =>
      _SetupOverlayWrapperState();
}

class _SetupOverlayWrapperState extends ConsumerState<SetupOverlayWrapper> {
  bool _shouldShow = false;
  bool _fadingOut = false;
  bool _hasCompletedOnce = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final gallery = ref.watch(galleryStateProvider);

    final isCurrentlyActive = auth.status == AuthStatus.authenticated &&
        !gallery.loadedFromCache &&
        gallery.isGeocoding &&
        !_hasCompletedOnce &&
        (gallery.geocodeTotal == 0 ||
            gallery.geocodeProcessed < gallery.geocodeTotal);

    if (isCurrentlyActive && !_shouldShow && !_fadingOut) {
      _shouldShow = true;
    }

    if (!isCurrentlyActive && _shouldShow && !_fadingOut) {
      _fadingOut = true;
      _hasCompletedOnce = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _shouldShow = false;
            _fadingOut = false;
          });
        }
      });
    }

    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (_shouldShow)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isCurrentlyActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !isCurrentlyActive,
                child: Material(
                  color: Colors.transparent,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.map_rounded,
                                          size: 48,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Preparing Your Atlas',
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Indexing and organizing your photos\n(${gallery.geocodeProcessed} / ${gallery.geocodeTotal})',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                            begin: 0.0,
                                            end: gallery.geocodeTotal > 0
                                                ? gallery.geocodeProcessed /
                                                      gallery.geocodeTotal
                                                : 0.0,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          curve: Curves.easeInOut,
                                          builder: (context, value, _) {
                                            return Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: LinearProgressIndicator(
                                                    value: value,
                                                    backgroundColor: Colors
                                                        .white
                                                        .withValues(alpha: 0.1),
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  '${(value * 100).toStringAsFixed(0)}%',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'This setup only happens on the first launch\nto map your travels safely.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white38,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
