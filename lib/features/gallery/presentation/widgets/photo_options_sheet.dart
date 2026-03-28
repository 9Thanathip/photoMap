import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../providers/gallery_notifier.dart';

class PhotoOptionsSheet extends StatelessWidget {
  const PhotoOptionsSheet({
    super.key,
    required this.photo,
    required this.onChangeLocation,
    required this.onDelete,
  });

  final PhotoItem photo;
  final VoidCallback onChangeLocation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Photo Options',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Change Location'),
          onTap: onChangeLocation,
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: onDelete,
        ),
        const Gap(8),
      ],
    );
  }
}
