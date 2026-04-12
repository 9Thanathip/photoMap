import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(80),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.photo_camera_rounded,
                  color: Colors.white, size: 44),
            ),
            const Gap(20),
            Text(
              'Jaruek',
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const Gap(6),
            Text(
              'Explore & Capture Thailand',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // const Gap(56),
            // SizedBox(
            //   width: 28,
            //   height: 28,
            //   child: CircularProgressIndicator(
            //     strokeWidth: 2.5,
            //     color: theme.colorScheme.primary,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
