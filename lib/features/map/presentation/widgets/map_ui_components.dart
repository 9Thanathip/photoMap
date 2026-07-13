import 'package:flutter/material.dart';

class MapActionButton extends StatelessWidget {
  const MapActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    return IconButton(
      icon: Icon(icon, size: 20, color: iconColor),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}
