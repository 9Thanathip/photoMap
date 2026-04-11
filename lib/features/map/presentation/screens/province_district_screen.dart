import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../gallery/presentation/providers/gallery_notifier.dart';
import '../../../gallery/presentation/widgets/album_card.dart';
import '../../../gallery/presentation/widgets/photo_tile.dart';
import '../../../gallery/presentation/widgets/photo_viewer_screen.dart';
import '../../../gallery/presentation/widgets/photos_tab.dart'
    show photoGridDelegate;
import '../providers/province_map_provider.dart';
import '../widgets/province_map_painter.dart';

const _albumGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  childAspectRatio: 0.92,
);

enum _ViewMode { map, grid }

class ProvinceDistrictScreen extends ConsumerStatefulWidget {
  const ProvinceDistrictScreen({super.key, required this.provinceName});

  final String provinceName;

  @override
  ConsumerState<ProvinceDistrictScreen> createState() =>
      _ProvinceDistrictScreenState();
}

class _ProvinceDistrictScreenState extends ConsumerState<ProvinceDistrictScreen>
    with TickerProviderStateMixin {
  String? _selectedDistrict;
  bool _goingDeeper = true;
  _ViewMode _viewMode = _ViewMode.map;
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _tickerController;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _transformController.dispose();
    _tickerController.dispose();
    super.dispose();
  }

  void _resetView() {
    final Matrix4 end = Matrix4.identity();
    final Matrix4 start = _transformController.value;

    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final CurvedAnimation curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    curve.addListener(() {
      _transformController.value = Matrix4Tween(
        begin: start,
        end: end,
      ).evaluate(curve);
    });

    animation.forward().then((_) => animation.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final byDistrict = gallery.photosByDistrict(widget.provinceName);
    final theme = Theme.of(context);

    final mapState = ref.watch(provinceMapProvider(widget.provinceName));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _selectedDistrict ?? widget.provinceName,
            key: ValueKey(_selectedDistrict ?? widget.provinceName),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        centerTitle: true,
        leading: _selectedDistrict != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() {
                  _goingDeeper = false;
                  _selectedDistrict = null;
                }),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_selectedDistrict == null)
            IconButton(
              icon: Icon(
                _viewMode == _ViewMode.map
                    ? Icons.grid_view_rounded
                    : Icons.map_outlined,
              ),
              onPressed: () => setState(() {
                _viewMode = _viewMode == _ViewMode.map
                    ? _ViewMode.grid
                    : _ViewMode.map;
              }),
            ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedDistrict != null
                ? _DistrictPhotosGrid(
                    key: ValueKey(_selectedDistrict),
                    photos: byDistrict[_selectedDistrict] ?? [],
                    districtName: _selectedDistrict!,
                  )
                : (_viewMode == _ViewMode.map
                      ? _DistrictsMap(
                          provinceName: widget.provinceName,
                          transformController: _transformController,
                          onSelectDistrict: (d) => setState(() {
                            _goingDeeper = true;
                            _selectedDistrict = d;
                          }),
                        )
                      : _DistrictsGrid(
                          key: const ValueKey('districts'),
                          byDistrict: byDistrict,
                          provinceName: widget.provinceName,
                          onSelectDistrict: (d) => setState(() {
                            _goingDeeper = true;
                            _selectedDistrict = d;
                          }),
                        )),
          ),
          if (_selectedDistrict == null &&
              _viewMode == _ViewMode.map &&
              mapState.error == null)
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: FloatingActionButton.small(
                onPressed: _resetView,
                child: const Icon(Icons.center_focus_strong_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Districts Map View ────────────────────────────────────────────────────────

class _DistrictsMap extends ConsumerStatefulWidget {
  const _DistrictsMap({
    required this.provinceName,
    required this.transformController,
    required this.onSelectDistrict,
  });

  final String provinceName;
  final TransformationController transformController;
  final void Function(String) onSelectDistrict;

  @override
  ConsumerState<_DistrictsMap> createState() => _DistrictsMapState();
}

class _DistrictsMapState extends ConsumerState<_DistrictsMap> {
  Offset? _tapDownPosition;
  DateTime _currentTime = DateTime.now();
  late final DateTime _openTime;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _openTime = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleMapTap(Offset globalPosition, List<DistrictShape> districts) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final canvasPos = renderBox.globalToLocal(globalPosition);
    final canvasSize = renderBox.size;

    Rect totalBounds = districts.first.bounds;
    for (final d in districts.skip(1)) {
      totalBounds = totalBounds.expandToInclude(d.bounds);
    }
    final scaleX = canvasSize.width / totalBounds.width;
    final scaleY = canvasSize.height / totalBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85;
    final offsetX =
        (canvasSize.width - totalBounds.width * scale) / 2 -
        totalBounds.left * scale;
    final offsetY =
        (canvasSize.height - totalBounds.height * scale) / 2 -
        totalBounds.top * scale;

    final dx = (canvasPos.dx - offsetX) / scale;
    final dy = (canvasPos.dy - offsetY) / scale;
    final point = Offset(dx, dy);

    for (final district in districts) {
      if (district.path.contains(point)) {
        widget.onSelectDistrict(district.name);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provinceMapProvider(widget.provinceName));

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Colors.grey.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(state.error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              "Showing grid view instead.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerDown: (e) => _tapDownPosition = e.position,
      onPointerUp: (e) {
        final down = _tapDownPosition;
        _tapDownPosition = null;
        if (down != null && (e.position - down).distance < 18) {
          _handleMapTap(e.position, state.districts);
        }
      },
      child: InteractiveViewer(
        transformationController: widget.transformController,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 8.0,
        child: Center(
          child: CustomPaint(
            size: const Size(1000, 1000),
            painter: ProvinceMapPainter(
              districts: state.districts,
              combinedPath: state.combinedPath,
              districtPhotos: state.districtPhotos,
              imageLoadTimes: state.imageLoadTimes,
              currentTime: _currentTime,
              openTime: _openTime,
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              strokeColor: Theme.of(
                context,
              ).colorScheme.outlineVariant.withAlpha(150),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

// ── Districts album grid ──────────────────────────────────────────────────────

class _DistrictsGrid extends StatelessWidget {
  const _DistrictsGrid({
    super.key,
    required this.byDistrict,
    required this.provinceName,
    required this.onSelectDistrict,
  });

  final Map<String, List<PhotoItem>> byDistrict;
  final String provinceName;
  final void Function(String) onSelectDistrict;

  @override
  Widget build(BuildContext context) {
    if (byDistrict.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(60),
            ),
            const SizedBox(height: 12),
            Text(
              'No photos in $provinceName',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final names = byDistrict.keys.where((k) => k != 'Unknown').toList()..sort();
    final unknownPhotos = byDistrict['Unknown'];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: _albumGridDelegate,
      itemCount: names.length + (unknownPhotos != null ? 1 : 0),
      itemBuilder: (_, i) {
        final name = i < names.length ? names[i] : 'Unknown';
        final photos = byDistrict[name]!;
        return AlbumCard(
          title: name,
          subtitle: '${photos.length} photos',
          coverPhoto: photos.first,
          onTap: () => onSelectDistrict(name),
        );
      },
    );
  }
}

// ── District photo grid ───────────────────────────────────────────────────────

class _DistrictPhotosGrid extends StatelessWidget {
  const _DistrictPhotosGrid({
    super.key,
    required this.photos,
    required this.districtName,
  });

  final List<PhotoItem> photos;
  final String districtName;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Center(
        child: Text(
          'No photos in $districtName',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sorted = [...photos]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return GridView.builder(
      padding: const EdgeInsets.all(1.5),
      gridDelegate: photoGridDelegate,
      itemCount: sorted.length,
      itemBuilder: (_, i) => PhotoTile(
        photo: sorted[i],
        onTap: () => _openViewer(context, sorted, i),
        onLongPress: () {},
      ),
    );
  }

  void _openViewer(BuildContext context, List<PhotoItem> photos, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: PhotoViewerScreen(photos: photos, initialIndex: index),
        ),
      ),
    );
  }
}
