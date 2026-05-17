import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/core/theme/app_tokens.dart';
import '../widgets/auth_brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      icon: Icons.photo_library_rounded,
      title: 'Capture Your\nMoments',
      description:
          'Organize and edit your photos with a beautiful, intuitive gallery experience.',
    ),
    _PageData(
      icon: Icons.map_rounded,
      title: 'Map Your\nJourney',
      description:
          'Pin your photos to locations and explore your memories on an interactive map.',
    ),
    _PageData(
      icon: Icons.emoji_events_rounded,
      title: 'Explore\nThailand',
      description:
          'Discover all 77 provinces and unlock achievements as you travel the kingdom.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: t.surfaceBase,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
          ),

          // ── Brand mark ──
          Positioned(
            top: top + 20,
            left: 24,
            child: const AuthBrandMark(iconSize: 32, labelSize: 17),
          ),

          // ── Skip ──
          if (!isLast)
            Positioned(
              top: top + 14,
              right: 12,
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ),

          // ── Bottom controls ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _page == i ? 26 : 8,
                        decoration: BoxDecoration(
                          color: _page == i ? t.accentGold : t.borderStrong,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const Gap(28),
                  Row(
                    children: [
                      if (_page > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Skip'),
                          ),
                        ),
                        const Gap(12),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(isLast ? 'Get Started' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = context.tokens;
    final art = size.width * 0.56;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: art,
            height: art,
            decoration: BoxDecoration(
              color: t.surfaceCard,
              borderRadius: BorderRadius.circular(art * 0.28),
              border: Border.all(color: t.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: t.accentGold.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: art * 0.5,
                height: art * 0.5,
                decoration: BoxDecoration(
                  color: t.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(art * 0.18),
                ),
                child: Icon(data.icon, size: 56, color: t.accentGold),
              ),
            ),
          ),
          const Gap(48),
          Text(
            data.title,
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.15,
              color: t.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          Text(
            data.description,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              color: t.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(150),
        ],
      ),
    );
  }
}
