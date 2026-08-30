import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'common_widgets/setup_progress_overlay.dart';
import 'features/gallery/presentation/providers/gallery_notifier.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/subscription/presentation/widgets/subscription_banner.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Jaruek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        // Setup wraps the banner, not the other way round: first-run indexing
        // is a blocking progress overlay and must not have an offer on top of
        // it.
        return SetupOverlayWrapper(
          child: SubscriptionBannerHost(child: child),
        );
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
        gallery.isFirstTimeNoCache &&
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
        ?widget.child,
        if (_shouldShow)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isCurrentlyActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !isCurrentlyActive,
                child: SetupProgressOverlay(
                  processed: gallery.geocodeProcessed,
                  total: gallery.geocodeTotal,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
