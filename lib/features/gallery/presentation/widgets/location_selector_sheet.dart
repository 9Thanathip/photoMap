import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/gallery_notifier.dart';
import 'sheet_handle.dart';

class LocationSelectorSheet extends ConsumerStatefulWidget {
  const LocationSelectorSheet({super.key, required this.photo});

  final PhotoItem photo;

  @override
  ConsumerState<LocationSelectorSheet> createState() =>
      _LocationSelectorSheetState();
}

class _LocationSelectorSheetState
    extends ConsumerState<LocationSelectorSheet> {
  late String _country;
  late String _province;

  @override
  void initState() {
    super.initState();
    _country =
        widget.photo.country.isEmpty ? 'Unknown' : widget.photo.country;
    _province =
        widget.photo.province.isEmpty ? 'Unknown' : widget.photo.province;
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.read(galleryStateProvider);
    final sortedCountries = ({...g.availableCountries, _country}.toList()
      ..sort());
    final provinces = g.availableProvinces(_country);
    final theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(title: 'Change Location'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Country',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: sortedCountries
                  .map((name) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: name == _country,
                          onSelected: (_) => setState(() {
                            _country = name;
                            _province = 'Unknown';
                          }),
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (provinces.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Province',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: provinces.length,
                itemBuilder: (_, i) {
                  final p = provinces[i];
                  return ListTile(
                    dense: true,
                    title: Text(p),
                    trailing: p == _province
                        ? Icon(Icons.check_circle,
                            color: theme.colorScheme.primary)
                        : null,
                    onTap: () => setState(() => _province = p),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(galleryStateProvider.notifier)
                    .updatePhotoLocation(
                        widget.photo.path, _country, _province);
              },
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
