import 'package:flutter/material.dart';
import 'package:photo_map/common_widgets/glass_card.dart';

enum ProvinceViewMode { map, grid }

class ProvinceHeader extends StatelessWidget {
  const ProvinceHeader({
    super.key,
    required this.title,
    required this.viewMode,
    required this.isSelectingDistrict,
    required this.onBack,
    required this.onToggleMode,
  });

  final String title;
  final ProvinceViewMode viewMode;
  final bool isSelectingDistrict;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassCard(
          onTap: onBack,
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: Colors.black.withOpacity(0.55),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isSelectingDistrict) ...[
          const SizedBox(width: 10),
          GlassCard(
            onTap: onToggleMode,
            padding: const EdgeInsets.all(10),
            child: Icon(
              viewMode == ProvinceViewMode.map
                  ? Icons.grid_view_rounded
                  : Icons.map_outlined,
              size: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
