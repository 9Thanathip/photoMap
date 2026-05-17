import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';

/// App icon + "Jaruek" wordmark — the same lockup as the splash screen,
/// reused across onboarding / login / register so the brand reads as one
/// continuous experience. [iconSize] scales the whole mark.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.iconSize = 44, this.labelSize = 22});

  final double iconSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(iconSize * 0.32),
          child: Image.asset(
            'assets/icon.png',
            width: iconSize,
            height: iconSize,
          ),
        ),
        Gap(iconSize * 0.28),
        Text(
          'Jaruek',
          style: GoogleFonts.poppins(
            fontSize: labelSize,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: t.textPrimary,
          ),
        ),
      ],
    );
  }
}
