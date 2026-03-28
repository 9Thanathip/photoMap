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
      body: Stack(
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.provinces.isEmpty)
            const Center(child: Text('No Map Data Found'))
          else
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.5,
              maxScale: 10,
              child: Center(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: ThailandMapPainter(
                    provinces: state.provinces,
                    provincePhotos: state.provincePhotos,
                    baseColor: const Color(0xFFF0F0F0),
                    strokeColor: Colors.white,
                  ),
                  child: const SizedBox.expand(),
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
