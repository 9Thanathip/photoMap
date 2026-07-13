import 'package:flutter/material.dart';
import 'package:photo_map/core/theme/app_palette.dart';

// Aliases kept for `const` usage sites (AlwaysStoppedAnimation, BoxDecoration).
const kGold1 = Palette.gold400;
const kGold2 = Palette.gold700;
const kGold3 = Palette.gold300;
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
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
      ),
    );
  }
}
