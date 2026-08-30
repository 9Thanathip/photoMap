import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

/// Which build this is.
///
/// The project already ships two of everything below Dart — bundle ids
/// (`com.thanathip.jaruek` and `.dev`), a Firebase project each under
/// `ios/config/`, an xcconfig per configuration, Android product flavors on the
/// `env` dimension. Nothing in Dart could tell them apart, so anything written
/// from a dev run landed on top of prod's. This is the missing half.
enum AppEnv {
  dev,
  prod;

  /// Set by tests only.
  @visibleForTesting
  static AppEnv? debugOverride;

  static AppEnv get current => debugOverride ?? _fromFlavor;

  static final AppEnv _fromFlavor = switch (appFlavor) {
    'prod' => AppEnv.prod,
    'dev' => AppEnv.dev,
    // No `--flavor` at all: a bare `flutter run`, or a test. Calling that prod
    // would point a debug build at live billing and the real Firebase project,
    // so it is the one guess worth never making.
    _ => AppEnv.dev,
  };

  bool get isDev => this == AppEnv.dev;
  bool get isProd => this == AppEnv.prod;

  /// Suffix for anything that must not be shared between builds — stored
  /// preferences above all. Both flavors can be installed side by side, but
  /// they are separate installs with separate storage; scoping keys keeps a
  /// key's meaning the same if that ever stops being true.
  String scopedKey(String key) => '${key}_$name';
}
