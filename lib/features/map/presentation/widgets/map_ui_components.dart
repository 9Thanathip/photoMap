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
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.black87),
      onPressed: onTap,
      tooltip: tooltip,
    );
  }
}
