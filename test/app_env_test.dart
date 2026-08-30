import 'package:flutter_test/flutter_test.dart';
import 'package:photo_map/core/config/app_env.dart';
import 'package:photo_map/features/subscription/domain/subscription_plan.dart';

void main() {
  tearDown(() => AppEnv.debugOverride = null);

  test('a build with no flavor is treated as dev', () {
    // `flutter test` and a bare `flutter run` pass no --flavor. Reading that as
    // prod would point a debug build at live billing and the real Firebase
    // project, so it is the one guess worth never making.
    expect(AppEnv.current, AppEnv.dev);
  });

  test('each build bills its own store product', () {
    // A sandbox product and a live one are separate records in App Store
    // Connect. A dev build charging the live id is a real charge.
    AppEnv.debugOverride = AppEnv.dev;
    final dev = SubscriptionPlan.current;
    AppEnv.debugOverride = AppEnv.prod;
    final prod = SubscriptionPlan.current;

    expect(dev.productId, isNot(prod.productId));
    expect(prod.productId, isNot(contains('.dev.')));
    // Same offer either way — only the record it bills differs.
    expect(dev.priceThb, prod.priceThb);
    expect(prod.priceThb, 29);
  });

  test('stored keys do not leak between builds', () {
    AppEnv.debugOverride = AppEnv.dev;
    final dev = AppEnv.current.scopedKey('some_flag');
    AppEnv.debugOverride = AppEnv.prod;
    final prod = AppEnv.current.scopedKey('some_flag');

    expect(dev, isNot(prod));
  });
}
