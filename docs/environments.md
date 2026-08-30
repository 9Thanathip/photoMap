# Environments (dev / prod)

Two build flavors, one Firebase project each. Both install on the same device at
once because dev carries a `.dev` bundle-id suffix.

| | dev | prod |
|---|---|---|
| Bundle / package | `com.thanathip.jaruek.dev` | `com.thanathip.jaruek` |
| App name | Jaruek Dev | Jaruek |
| Firebase project | `jaruek-dev` (32856376212) | `jaruek-f2b9e` (593468084945) |
| Firestore | `countries` @ asia-southeast3 | `countries` @ asia-southeast3 |
| Android config | `android/app/src/dev/google-services.json` | `android/app/src/prod/google-services.json` |
| iOS config | `ios/config/dev/GoogleService-Info.plist` | `ios/config/prod/GoogleService-Info.plist` |

Neither project has a `(default)` Firestore database — only the named
`countries` one, which is what `CountryRepository` talks to.

`.firebaserc` maps the CLI aliases: `firebase use dev` / `firebase use prod`,
or `--project dev` on any command.

## Running

```sh
flutter run    --flavor dev  -d <device>
flutter run    --flavor prod -d <device>
flutter build apk  --flavor prod --release
flutter build ipa  --flavor prod
```

Plain `flutter run` with no `--flavor` still works on iOS and resolves to prod
(the stock `Debug`/`Release`/`Profile` configs carry `FIREBASE_CONFIG_DIR=prod`).
Android has no default flavor, so `--flavor` is required there.

`appFlavor` from `package:flutter/services.dart` reports the running flavor at
runtime — Flutter passes it in automatically, no `--dart-define` needed.

## How the switch works

**Android** — `productFlavors` in `android/app/build.gradle.kts`. The
google-services Gradle plugin picks `src/<flavor>/google-services.json` on its
own. App name comes from a per-flavor `resValue` behind `@string/app_name`.

**iOS** — six build configurations (`Debug-dev`, `Release-dev`, `Profile-dev`
and the `-prod` trio) plus matching `dev` / `prod` schemes. Each config sets
`FIREBASE_CONFIG_DIR` and `APP_DISPLAY_NAME`, and points at
`ios/Flutter/<Config>.xcconfig` so it picks up the right CocoaPods xcconfig.

The `Copy Firebase config for flavor` script phase on the Runner target then:

1. copies `ios/config/$FIREBASE_CONFIG_DIR/GoogleService-Info.plist` into the
   built app — `google_sign_in` reads `CLIENT_ID` straight out of it;
2. rewrites `GIDClientID` and the OAuth `CFBundleURLSchemes` entry in the built
   `Info.plist` from that same file, since the redirect scheme is per-project.
   If the plist has no `CLIENT_ID` (Google sign-in not enabled on that project)
   it strips both keys instead, so a build can never inherit prod's scheme.

Swapping a flavor's Firebase project means replacing one file — the values
checked into `ios/Runner/Info.plist` are only placeholders the phase overwrites.

## Auth

Email/Password and Google are both on for dev — the app uses both
(`firebase_auth_repository.dart`). The Android debug SHA-1 (`0e67a37b…`) and
SHA-256 are registered on the dev app; it is the same `~/.android/debug.keystore`
prod uses, so the hashes match.

Re-pull the config files after any change to sign-in providers — the OAuth client
ids live inside them:

```sh
firebase apps:sdkconfig IOS     1:32856376212:ios:dc0188d1e636345742c581 \
  --project dev --out ios/config/dev/GoogleService-Info.plist
firebase apps:sdkconfig ANDROID 1:32856376212:android:716047e4bf6082f342c581 \
  --project dev --out android/app/src/dev/google-services.json
```

## Firestore rules

Dev's rules live in `firebase/dev.firestore.rules` and are deployed with:

```sh
firebase deploy --only firestore:rules --project jaruek-dev --config <config.json>
```

There is deliberately **no `firebase.json` at the repo root**. Prod's rules are
not in this repo — the Rules API is not reachable from the Firebase CLI, so there
is nothing to mirror them from — and a root config would let a stray
`firebase deploy --project prod` overwrite prod with dev's ruleset. Deploy with
an explicit `--config` pointing at a throwaway file instead:

```json
{ "firestore": { "database": "countries", "rules": "firebase/dev.firestore.rules" } }
```

## Still to do on jaruek-dev

**Seed the `countries` collection** — dev's database is empty. Prod's copy cannot
be read from here (the Firestore REST API refuses named-database reads on
`jaruek-f2b9e` for want of billing, and the CLI has no export command), so the
documents have to be re-entered in the dev console or written by a script.

This is not blocking: `Country.thailand` is hardcoded in
`country_provider.dart:51` and always prepended, so dev runs fine on Thailand.
An empty collection just means no extra downloadable countries.

Prod has a default Storage bucket that dev does not, but nothing in the app uses
`firebase_storage`, so it is not worth replicating.
