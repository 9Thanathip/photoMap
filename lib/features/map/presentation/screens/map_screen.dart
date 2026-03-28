import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/map_provider.dart';
import '../widgets/thailand_map_painter.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thailand Photo Map'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(mapProvider.notifier).loadMap(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.provinces.isEmpty)
            const Center(child: Text('No Map Data Found'))
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(50),
                minScale: 0.1,
                maxScale: 10,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 0.6, // Typical proportional aspect ratio for Thailand
                    child: CustomPaint(
                      painter: ThailandMapPainter(
                        provinces: state.provinces,
                        provincePhotos: state.provincePhotos,
                        baseColor: const Color(0xFFF0F0F0),
                        strokeColor: Colors.white,
                      ),
                      child: Container(),
                    ),
                  ),
                ),
              ),
            ),
          
          // Floating overlay items like the screenshot
          PositionBag(),
        ],
      ),
    );
  }
}

class PositionBag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            onPressed: () {},
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.settings),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            mini: true,
            onPressed: () {},
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
    );
  }
}
