# CLAUDE.md — photo_map

Project rules + conventions. Read before writing code. Keep new code matching what's here.

## What this is

Flutter app: photo mapping + travel tracking (Thailand-first, multi-country).
Photos → geocoded → painted onto province/country maps. Achievements per province.

- **State**: Riverpod (`flutter_riverpod ^2.5`)
- **Routing**: `go_router ^14`
- **Backend**: Firebase (Auth + Firestore), `photo_manager` for device photos
- **Localization**: EN + TH via generated `AppLocalizations` (`generate: true`)
- SDK `^3.10`. Analyzer: `flutter_lints`. Keep `flutter analyze` at **0 issues**.

## Architecture — feature-first + layers

```
lib/
  app.dart, main.dart          # root app + bootstrap (Firebase, prefs, ProviderScope overrides)
  common_widgets/              # cross-feature reusable widgets (AppButton, GlassCard, ...)
  core/
    providers/                 # app-wide providers (locale, theme)
    router/                    # go_router config
    services/                  # infra (cache, geo, session cleaner)
    theme/                     # palette, tokens, theme
  features/<feature>/
    data/                      # repository impls, data sources
    domain/                    # models + abstract repository interfaces
    presentation/
      providers/               # StateNotifier + immutable State
      screens/                 # full-page routes
      widgets/                 # feature-scoped widgets (subfoldered by area)
  l10n/                        # arb files + generated localizations + l10n_x helpers
```

Rules:
- New feature → mirror this layout. Don't put business logic in widgets.
- `domain/` holds **abstract** repository + plain models. `data/` implements it.
  See `features/auth/domain/auth_repository.dart` (interface) → `data/firebase_auth_repository.dart` (impl) + `data/mock_auth_repository.dart` (test/dev).
- A widget imports across features only through `presentation/providers` or `common_widgets` — not another feature's widgets.

## State management — Riverpod

- Use **`StateNotifier` + immutable state class** (this repo's standard; 10 notifiers). Do NOT introduce the new `Notifier`/`AsyncNotifier` API — keep consistency.
- State class pattern: `final` fields, `const`/named constructor, `copyWith`. Add `clearX` bool flags to `copyWith` when a field must be nullable-resettable (see `MapState.copyWith(clearViewBox)`).
- Named constructors as semantic factories for state variants (see `AuthState.authenticated(...)`, `.loading()`, `.unauthenticated()`).
- Provider naming: **plain `xProvider`** for the exposed provider (e.g. `mapProvider`, `countryProvider`). `authNotifierProvider` is the lone historical exception — don't copy it; prefer `xProvider`.
- Parameterized providers → `StateNotifierProvider.family` with a `Params` class (see `provinceMapProvider` / `ProvinceMapParams`).
- Cross-provider reactions: `ref.listen(otherProvider, (prev, next) {...})` inside the notifier ctor (see `MapNotifier` listening to gallery/cover/country).
- Guard async `state =` writes with `if (mounted)` after every `await`.
- Widgets: `ConsumerWidget` / `ConsumerStatefulWidget`. `ref.watch` to rebuild, `ref.read(...notifier)` for actions.

## Theming — tokens, never raw colors

- **Always** pull colors from semantic tokens: `context.tokens.textPrimary`, `.surfaceCard`, `.accentGold`, etc. Defined in `core/theme/app_tokens.dart` (`AppTokens` ThemeExtension, light + dark variants).
- Raw hex belongs only in `core/theme/app_palette.dart` (`Palette.*`). Tokens reference palette; widgets reference tokens.
- Brightness-aware helpers on `BuildContext`: `context.isDark`, `context.dim(light, dark)`, `context.dimW(a)`, `context.dimB(a)`.
- When you need a new roled color, add a **token** — don't hardcode `Colors.white.withValues(...)` in a widget. (Bottom-nav inactive uses `t.textSecondary`, not a hardcoded alpha — follow that.)
- Opacity: use `.withValues(alpha: x)` — **never** deprecated `.withOpacity(x)`.
- For a color's contrasting foreground, use `ThemeData.estimateBrightnessForColor(c)` (see color swatch check-mark + `ColorCard`).

## Routing

- All routes in `core/router/app_router.dart` via `routerProvider`.
- Auth-gated redirect logic lives in the `redirect` callback keyed on `AuthStatus`. Add new gated paths to the right list there.
- Main tabs = `StatefulShellRoute.indexedStack` (gallery/map/province/settings). Page transitions via the shared `_fade(...)` helper.

## Localization

- No hardcoded user-facing strings. Add keys to `lib/l10n/app_en.arb` + `lib/l10n/app_th.arb`, run `flutter gen-l10n` (or build — `generate: true`).
- Access: `final l10n = AppLocalizations.of(context);` then `l10n.someKey`.
- Shared/derived label logic (months, view-mode names, film presets) goes in the `AppL10nX` extension in `l10n/l10n_x.dart` — not duplicated per screen.

## Services / data

- Infra with no UI → `core/services/` (e.g. `CacheService` for on-disk JSON).
- Logging: use **`debugPrint`**, never `print`. (Needs `import 'package:flutter/foundation.dart';` if no flutter import present.)
- Wrap file/network I/O in try/catch; on failure `debugPrint` + return null/empty, don't throw into UI (see `CacheService`).

## Style conventions

- Single quotes for strings/imports.
- `const` aggressively (constructors, presets like `kProvincePresets`).
- Wildcard unused params: `(_, _)` / `(_, _, _)` — not `(_, __)`.
- `if` bodies always braced (even one-liners).
- Section headers in long widget trees: `// ── Label ──`.
- Comments explain **why** (flicker avoidance, race guards), not what. Match existing density.

## Before finishing any change

1. `flutter analyze` → must be **0 issues**.
2. Compile check without a device: `flutter build bundle` (compiles Dart to kernel).
3. Full compile / run on device: `flutter run -d 00008150-00025D5434C0401C` (physical "T H A N A T H I P", needs codesign).
4. Touched UI colors → verify **both** light and dark mode.
5. Only one test exists (`test/widget_test.dart`); this project verifies by running, not unit tests.
