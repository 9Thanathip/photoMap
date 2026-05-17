import 'package:flutter/material.dart';

/// The official multi-colour Google "G", drawn as a vector so it stays
/// crisp at any size and needs no asset bundling.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.9824, h * 0.5115)
        ..cubicTo(w * 0.9824, h * 0.4751, w * 0.9791, h * 0.4401, w * 0.9730,
            h * 0.4065)
        ..lineTo(w * 0.5000, h * 0.4065)
        ..lineTo(w * 0.5000, h * 0.5961)
        ..lineTo(w * 0.7716, h * 0.5961)
        ..cubicTo(w * 0.7599, h * 0.6591, w * 0.7244, h * 0.7125, w * 0.6710,
            h * 0.7482)
        ..lineTo(w * 0.6710, h * 0.8715)
        ..lineTo(w * 0.8338, h * 0.8715)
        ..cubicTo(w * 0.9291, h * 0.7838, w * 0.9824, h * 0.6546, w * 0.9824,
            h * 0.5115)
        ..close(),
      paint,
    );

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5000, h * 1.0000)
        ..cubicTo(w * 0.6350, h * 1.0000, w * 0.7482, h * 0.9553, w * 0.8338,
            h * 0.8715)
        ..lineTo(w * 0.6710, h * 0.7482)
        ..cubicTo(w * 0.6259, h * 0.7785, w * 0.5681, h * 0.7964, w * 0.5000,
            h * 0.7964)
        ..cubicTo(w * 0.3697, h * 0.7964, w * 0.2594, h * 0.7083, w * 0.2201,
            h * 0.5899)
        ..lineTo(w * 0.0518, h * 0.5899)
        ..lineTo(w * 0.0518, h * 0.7171)
        ..cubicTo(w * 0.1370, h * 0.8862, w * 0.3119, h * 1.0000, w * 0.5000,
            h * 1.0000)
        ..close(),
      paint,
    );

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.2201, h * 0.5899)
        ..cubicTo(w * 0.2101, h * 0.5597, w * 0.2044, h * 0.5274, w * 0.2044,
            h * 0.4942)
        ..cubicTo(w * 0.2044, h * 0.4610, w * 0.2101, h * 0.4287, w * 0.2201,
            h * 0.3985)
        ..lineTo(w * 0.2201, h * 0.2713)
        ..lineTo(w * 0.0518, h * 0.2713)
        ..cubicTo(w * 0.0188, h * 0.3370, w * 0.0000, h * 0.4113, w * 0.0000,
            h * 0.4942)
        ..cubicTo(w * 0.0000, h * 0.5771, w * 0.0188, h * 0.6514, w * 0.0518,
            h * 0.7171)
        ..lineTo(w * 0.2201, h * 0.5899)
        ..close(),
      paint,
    );

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5000, h * 0.1920)
        ..cubicTo(w * 0.5736, h * 0.1920, w * 0.6397, h * 0.2173, w * 0.6917,
            h * 0.2669)
        ..lineTo(w * 0.8374, h * 0.1211)
        ..cubicTo(w * 0.7479, h * 0.0377, w * 0.6347, h * 0.0000, w * 0.5000,
            h * 0.0000)
        ..cubicTo(w * 0.3119, h * 0.0000, w * 0.1370, h * 0.1138, w * 0.0518,
            h * 0.2713)
        ..lineTo(w * 0.2201, h * 0.3985)
        ..cubicTo(w * 0.2594, h * 0.2801, w * 0.3697, h * 0.1920, w * 0.5000,
            h * 0.1920)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
