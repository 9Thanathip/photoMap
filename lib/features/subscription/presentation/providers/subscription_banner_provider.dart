import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/core/config/app_env.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

@immutable
class SubscriptionBannerState {
  const SubscriptionBannerState({
    this.visible = false,
    this.optOut = false,
    this.ready = false,
  });

  /// The banner is on screen.
  final bool visible;

  /// The "don't show again" box as it currently sits. Only acted on when the
  /// banner is closed, so ticking it and then changing your mind costs
  /// nothing.
  final bool optOut;

  /// The stored preference has been read. Nothing shows before this, or a
  /// user who opted out months ago sees the banner flash on every cold start.
  final bool ready;

  SubscriptionBannerState copyWith({
    bool? visible,
    bool? optOut,
    bool? ready,
  }) =>
      SubscriptionBannerState(
        visible: visible ?? this.visible,
        optOut: optOut ?? this.optOut,
        ready: ready ?? this.ready,
      );
}

class SubscriptionBannerNotifier extends StateNotifier<SubscriptionBannerState> {
  SubscriptionBannerNotifier(this._ref)
      : super(const SubscriptionBannerState()) {
    _load();
    // Not on the login or verification screens — the offer belongs after the
    // door, not in front of it.
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, next) {
        if (next.status == AuthStatus.authenticated) _showOnce();
      },
      fireImmediately: true,
    );
  }

  final Ref _ref;

  /// Scoped to the build. Dismissing the banner while testing a dev build must
  /// not silence it for the same person on the store build.
  static String get _key =>
      AppEnv.current.scopedKey('subscription_banner_suppressed');

  /// The stored answer to "don't show again". Kept off the state because no
  /// widget needs it — the banner simply never becomes visible.
  bool _suppressed = false;

  /// Once per launch, however many times auth re-reports itself.
  bool _shownThisLaunch = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _suppressed = prefs.getBool(_key) ?? false;
    if (!mounted) return;
    state = state.copyWith(ready: true);
    // Auth may well have settled while this was reading.
    _showOnce();
  }

  void _showOnce() {
    if (!mounted || !state.ready || _suppressed || _shownThisLaunch) return;
    if (_ref.read(authNotifierProvider).status != AuthStatus.authenticated) {
      return;
    }
    _shownThisLaunch = true;
    state = state.copyWith(visible: true);
  }

  void setOptOut(bool value) {
    if (mounted) state = state.copyWith(optOut: value);
  }

  /// Closes the banner, and remembers the choice if the box was ticked.
  Future<void> dismiss() async {
    final optOut = state.optOut;
    if (mounted) state = state.copyWith(visible: false);
    if (!optOut) return;
    _suppressed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

final subscriptionBannerProvider =
    StateNotifierProvider<SubscriptionBannerNotifier, SubscriptionBannerState>(
  SubscriptionBannerNotifier.new,
);
