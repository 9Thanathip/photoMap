import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/config/app_env.dart';
import 'package:photo_map/core/theme/app_theme.dart';
import 'package:photo_map/features/auth/data/mock_auth_repository.dart';
import 'package:photo_map/features/auth/domain/auth_repository.dart';
import 'package:photo_map/features/auth/presentation/providers/auth_provider.dart';
import 'package:photo_map/features/subscription/presentation/widgets/subscription_banner.dart';
import 'package:photo_map/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed in and verified, which is the only state the offer shows in.
class _SignedIn extends MockAuthRepository {
  @override
  Stream<AuthUser?> userChanges() => Stream<AuthUser?>.value(
        const AuthUser(uid: 'u1', email: 'a@b.co', emailVerified: true),
      );
}

/// Sitting on the login screen.
class _SignedOut extends MockAuthRepository {
  @override
  Stream<AuthUser?> userChanges() => Stream<AuthUser?>.value(null);
}

Future<void> _pump(WidgetTester tester, {AuthRepository? repo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo ?? _SignedIn()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SubscriptionBannerHost(child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scoped per build, so a dev run cannot silence the banner on the store one.
final String _suppressedKey =
    AppEnv.current.scopedKey('subscription_banner_suppressed');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the offer greets a signed-in user', (tester) async {
    await _pump(tester);
    expect(find.byType(SubscriptionBanner), findsOneWidget);
    expect(find.text('฿29 / month'), findsOneWidget);
  });

  testWidgets('it stays away from the login screen', (tester) async {
    // The offer belongs after the door, not in front of it.
    await _pump(tester, repo: _SignedOut());
    expect(find.byType(SubscriptionBanner), findsNothing);
  });

  testWidgets('dismissing without ticking leaves it to come back',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionBanner), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_suppressedKey), isNull);
  });

  testWidgets('ticking the box is what makes the choice stick', (tester) async {
    await _pump(tester);
    await tester.tap(find.text("Don't show this again"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_suppressedKey), isTrue);
  });

  testWidgets('a stored opt-out is honoured on the next launch',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{_suppressedKey: true},
    );
    await _pump(tester);
    expect(find.byType(SubscriptionBanner), findsNothing);
  });

  testWidgets('it shows once, not on every auth tick', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionBanner), findsNothing);

    // A rebuild must not bring it back — the user already answered.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SubscriptionBanner), findsNothing);
  });
}
