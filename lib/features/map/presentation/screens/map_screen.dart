import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/map_provider.dart';
import '../widgets/thailand_map_painter.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _ticker = createTicker((elapsed) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    imageLoadTimes: state.imageLoadTimes,
                    currentTime: _currentTime,
                    openTime: _openTime,
                    baseColor: const Color(0xFFD9D9D9),
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
