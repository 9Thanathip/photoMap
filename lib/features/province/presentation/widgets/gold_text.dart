import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kGold1 = Color(0xFFFFD060);
const kGold2 = Color(0xFFB8860B);
const kGold3 = Color(0xFFFFF0A0);
const kGoldGrad = LinearGradient(colors: [kGold2, kGold1]);

class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, required this.fontSize, required this.fontWeight});

  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [kGold2, kGold1, kGold3, kGold1],
        stops: [0.0, 0.4, 0.6, 1.0],
      ).createShader(b),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Shared BuildContext helpers used across achievement widgets
extension AchievementContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color dimW(double a) => Colors.white.withValues(alpha: a);
  Color dimB(double a) => Colors.black.withValues(alpha: a);
  Color dim(double light, double dark) => isDark ? dimW(dark) : dimB(light);
}
