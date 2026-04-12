import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/glass_card.dart';

class NationalMapHeader extends StatelessWidget {
  const NationalMapHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 15,
            color: Colors.black.withOpacity(0.55),
          ),
          const SizedBox(width: 6),
          const Text(
            'Thailand',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
