import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static final _markers = [
    _MarkerData(LatLng(13.7563, 100.5018), 'Bangkok', Icons.location_city),
    _MarkerData(LatLng(18.7883, 98.9853), 'Chiang Mai', Icons.landscape),
    _MarkerData(LatLng(7.8804, 98.3923), 'Phuket', Icons.beach_access),
    _MarkerData(LatLng(12.9236, 100.8825), 'Pattaya', Icons.waves),
    _MarkerData(LatLng(14.3492, 100.5613), 'Ayutthaya', Icons.account_balance),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(13.0, 101.0),
          initialZoom: 6.0,
          minZoom: 4,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.photo_map',
          ),
          MarkerLayer(
            markers: _markers
                .map(
                  (m) => Marker(
                    point: m.position,
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => _showMarkerInfo(context, m),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(m.icon, color: Colors.white, size: 18),
                          ),
                          Container(
                            width: 2,
                            height: 8,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }

  void _showMarkerInfo(BuildContext context, _MarkerData marker) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    marker.icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Gap(12),
                Text(
                  marker.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Gap(16),
            Text(
              '${marker.position.latitude.toStringAsFixed(4)}° N, '
              '${marker.position.longitude.toStringAsFixed(4)}° E',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Gap(16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('View Photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerData {
  const _MarkerData(this.position, this.label, this.icon);

  final LatLng position;
  final String label;
  final IconData icon;
}
