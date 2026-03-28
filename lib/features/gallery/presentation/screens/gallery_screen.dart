import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../features/province/data/province_data.dart';
import '../providers/gallery_notifier.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(galleryStateProvider);
    final theme = Theme.of(context);
    final allProvinces = ['All', ...thaiProvinces.map((p) => p.name).toList()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(galleryStateProvider.notifier).reloadPhotos(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Province Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Province',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: gallery.selectedProvince,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: allProvinces.map((province) {
                      return DropdownMenuItem(
                        value: province,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(province),
                        ),
                      );
                    }).toList(),
                    onChanged: (province) {
                      if (province != null) {
                        ref
                            .read(galleryStateProvider.notifier)
                            .selectProvince(province);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Photos Grid
          Expanded(
            child: _buildGalleryContent(
              context,
              ref,
              gallery,
              allProvinces,
              theme,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickImage(context, ref, gallery.selectedProvince),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add Photo'),
      ),
    );
  }

  Widget _buildGalleryContent(
    BuildContext context,
    WidgetRef ref,
    GalleryState gallery,
    List<String> provinces,
    ThemeData theme,
  ) {
    if (gallery.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
            const Gap(16),
            Text(
              'Loading photos...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (gallery.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error.withAlpha(128),
            ),
            const Gap(16),
            Text(
              'Error',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const Gap(8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                gallery.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final currentPhotos = gallery.getPhotosForProvince(gallery.selectedProvince);

    if (currentPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const Gap(16),
            Text(
              'No photos in ${gallery.selectedProvince}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Text(
              'Tap the button below to add photos',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: currentPhotos.length,
      itemBuilder: (context, index) {
        final photo = currentPhotos[index];
        return GestureDetector(
          onTap: () => _showPhotoEditor(context, photo, index, ref, gallery),
          onLongPress: () => _showPhotoOptions(
            context,
            ref,
            gallery.selectedProvince,
            index,
            provinces,
          ),
          child: Hero(
            tag: 'photo_${gallery.selectedProvince}_$index',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: FileImage(File(photo.path)),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDate(photo.timestamp),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _pickImage(BuildContext context, WidgetRef ref, String province) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      ref.read(galleryStateProvider.notifier).addPhoto(image.path, province);
    }
  }

  void _showPhotoEditor(
    BuildContext context,
    PhotoItem photo,
    int index,
    WidgetRef ref,
    GalleryState gallery,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoEditorSheet(
        photo: photo,
        index: index,
        province: gallery.selectedProvince,
        ref: ref,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String province,
    int index,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(galleryStateProvider.notifier)
                  .removePhoto(province, index);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(
    BuildContext context,
    WidgetRef ref,
    String currentProvince,
    int index,
    List<String> provinces,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Photo Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Change Province'),
            onTap: () {
              Navigator.pop(ctx);
              _showProvinceSelector(
                context,
                ref,
                currentProvince,
                index,
                provinces,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, ref, currentProvince, index);
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void _showProvinceSelector(
    BuildContext context,
    WidgetRef ref,
    String currentProvince,
    int index,
    List<String> provinces,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Province'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provinces.length,
            itemBuilder: (_, i) {
              final province = provinces[i];
              final isSelected = province == currentProvince;
              return ListTile(
                title: Text(province),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: isSelected
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        ref
                            .read(galleryStateProvider.notifier)
                            .updatePhotoProvince(
                              currentProvince,
                              index,
                              province,
                            );
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
}

class _PhotoEditorSheet extends ConsumerStatefulWidget {
  const _PhotoEditorSheet({
    required this.photo,
    required this.index,
    required this.province,
    required this.ref,
  });

  final PhotoItem photo;
  final int index;
  final String province;
  final WidgetRef ref;

  @override
  ConsumerState<_PhotoEditorSheet> createState() => _PhotoEditorSheetState();
}

class _PhotoEditorSheetState extends ConsumerState<_PhotoEditorSheet> {
  int _selectedFilter = 0;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;

  static const _filters = [
    _Filter('Original', Colors.transparent),
    _Filter('Warm', Color(0xFFFF6B35)),
    _Filter('Cool', Color(0xFF4FC3F7)),
    _Filter('B&W', Colors.grey),
    _Filter('Vivid', Color(0xFFAB47BC)),
    _Filter('Fade', Color(0xFFB0BEC5)),
    _Filter('Drama', Color(0xFF37474F)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Text(
                  'Edit Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            // Preview
            Expanded(
              child: Hero(
                tag: 'photo_${widget.province}_${widget.index}',
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _selectedFilter == 0
                        ? Colors.transparent
                        : _filters[_selectedFilter].color.withAlpha(60),
                    BlendMode.overlay,
                  ),
                  child: Image.file(
                    File(widget.photo.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const Gap(12),
            // Filter presets
            SizedBox(
              height: 90,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final isSelected = _selectedFilter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  i == 0
                                      ? Colors.transparent
                                      : _filters[i].color.withAlpha(80),
                                  BlendMode.overlay,
                                ),
                                child: Image.file(
                                  File(widget.photo.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const Gap(4),
                          Text(
                            _filters[i].name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(8),
            // Adjustments
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _Slider(
                    label: 'Brightness',
                    icon: Icons.brightness_6_outlined,
                    value: _brightness,
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                  _Slider(
                    label: 'Contrast',
                    icon: Icons.contrast_outlined,
                    value: _contrast,
                    onChanged: (v) => setState(() => _contrast = v),
                  ),
                  _Slider(
                    label: 'Saturation',
                    icon: Icons.invert_colors_outlined,
                    value: _saturation,
                    onChanged: (v) => setState(() => _saturation = v),
                  ),
                ],
              ),
            ),
            Gap(MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const Gap(8),
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _Filter {
  const _Filter(this.name, this.color);

  final String name;
  final Color color;
}
