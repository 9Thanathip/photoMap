import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_map/common_widgets/app_button.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';

import '../../domain/subscription_plan.dart';
import '../providers/subscription_banner_provider.dart';

/// Puts the launch offer over [child] when the provider says to.
///
/// An overlay rather than a route: this sits in `MaterialApp.builder`, above
/// the router's Navigator, so there is no Navigator to push onto — the same
/// reason `SetupOverlayWrapper` next to it is built this way.
class SubscriptionBannerHost extends ConsumerWidget {
  const SubscriptionBannerHost({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      subscriptionBannerProvider.select((s) => s.visible),
    );
    return Stack(
      children: [
        ?child,
        if (visible) const Positioned.fill(child: SubscriptionBanner()),
      ],
    );
  }
}

/// The launch offer: what it is, what it costs, and two ways out.
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;
    final optOut = ref.watch(subscriptionBannerProvider.select((s) => s.optOut));
    final notifier = ref.read(subscriptionBannerProvider.notifier);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tapping away is a dismissal like any other, so it honours the box.
          Positioned.fill(
            child: GestureDetector(
              onTap: notifier.dismiss,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(color: t.scrimMedium),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                decoration: BoxDecoration(
                  color: t.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: t.glassShadow,
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.accentGold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.flare_rounded,
                        size: 28,
                        color: t.accentGold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.subscriptionTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.subscriptionSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.subscriptionPrice(
                        '฿${SubscriptionPlan.current.priceThb}',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: t.accentGold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: l10n.subscriptionCta,
                        // Closes the banner and nothing more. There is no
                        // billing in this app yet: charging for this needs
                        // `in_app_purchase`, a StoreKit subscription product in
                        // App Store Connect, and somewhere to hold entitlement.
                        // This is the hook to replace when that exists.
                        onPressed: notifier.dismiss,
                      ),
                    ),
                    TextButton(
                      onPressed: notifier.dismiss,
                      child: Text(
                        l10n.subscriptionLater,
                        style: TextStyle(color: t.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _OptOutRow(
                      checked: optOut,
                      onChanged: notifier.setOptOut,
                      label: l10n.subscriptionDontShowAgain,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole row is the hit target — a 20pt checkbox on its own is not one.
class _OptOutRow extends StatelessWidget {
  const _OptOutRow({
    required this.checked,
    required this.onChanged,
    required this.label,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: t.accentGold,
                checkColor: t.textOnAccent,
                side: BorderSide(color: t.borderStrong, width: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: t.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
