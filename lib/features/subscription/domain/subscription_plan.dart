import 'package:flutter/foundation.dart';
import 'package:photo_map/core/config/app_env.dart';

/// The subscription the launch banner sells.
@immutable
class SubscriptionPlan {
  const SubscriptionPlan({required this.productId, required this.priceThb});

  /// The store record to charge against.
  ///
  /// Split per environment because a sandbox product and a live one are
  /// different records in App Store Connect and Play Console, and a dev build
  /// billing the live id is a real charge on a real card.
  final String productId;

  /// Monthly price in baht. One number, so the banner copy and any future
  /// checkout can never disagree.
  final int priceThb;

  static const SubscriptionPlan _prod = SubscriptionPlan(
    productId: 'com.thanathip.jaruek.premium.monthly',
    priceThb: 29,
  );

  static const SubscriptionPlan _dev = SubscriptionPlan(
    productId: 'com.thanathip.jaruek.dev.premium.monthly',
    priceThb: 29,
  );

  static SubscriptionPlan get current =>
      AppEnv.current.isProd ? _prod : _dev;
}
