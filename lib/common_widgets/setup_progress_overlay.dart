import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_icons.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import 'package:photo_map/l10n/app_localizations.dart';

/// First-run progress while the library is being read and geocoded.
///
/// Purely presentational — it takes two numbers, so the counting lives with
/// the gallery and this can be looked at in a test without a ProviderScope.
class SetupProgressOverlay extends StatelessWidget {
  const SetupProgressOverlay({
    super.key,
    required this.processed,
    required this.total,
  });

  final int processed;
  final int total;

  double get _fraction => total > 0 ? (processed / total).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: ColoredBox(color: t.scrimStrong),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.accentGold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.map_rounded,
                        size: 32,
                        color: t.accentGold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.setupPreparingAtlas,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.setupIndexingPhotos(processed, total),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _fraction),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      builder: (context, value, _) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: t.surfaceMuted,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(t.accentGold),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.setupFirstLaunchNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: t.textTertiary,
                      ),
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
