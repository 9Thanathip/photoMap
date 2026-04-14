import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';

// ── District counts ────────────────────────────────────────────────────────────

const Map<String, int> _kDistrictCount = {
  'Amnat Charoen': 7, 'Ang Thong': 7, 'Bangkok': 50, 'Bueng Kan': 8,
  'Buriram': 23, 'Chachoengsao': 11, 'Chainat': 8, 'Chaiyaphum': 16,
  'Chanthaburi': 10, 'Chiang Mai': 25, 'Chiang Rai': 18, 'Chonburi': 11,
  'Chumphon': 8, 'Kalasin': 18, 'Kamphaeng Phet': 11, 'Kanchanaburi': 13,
  'Khon Kaen': 26, 'Krabi': 8, 'Lampang': 13, 'Lamphun': 8, 'Loei': 14,
  'Lopburi': 11, 'Mae Hong Son': 7, 'Maha Sarakham': 13, 'Mukdahan': 7,
  'Nakhon Nayok': 4, 'Nakhon Pathom': 7, 'Nakhon Phanom': 12,
  'Nakhon Ratchasima': 32, 'Nakhon Sawan': 15, 'Nakhon Si Thammarat': 23,
  'Nan': 15, 'Narathiwat': 13, 'Nong Bua Lamphu': 6, 'Nong Khai': 9,
  'Nonthaburi': 6, 'Pathum Thani': 7, 'Pattani': 12, 'Phang Nga': 8,
  'Phatthalung': 11, 'Phayao': 9, 'Phetchabun': 11, 'Phetchaburi': 8,
  'Phichit': 12, 'Phitsanulok': 9, 'Phra Nakhon Si Ayutthaya': 16,
  'Phrae': 8, 'Phuket': 3, 'Prachin Buri': 7, 'Prachuap Khiri Khan': 8,
  'Ranong': 5, 'Ratchaburi': 10, 'Rayong': 8, 'Roi Et': 20, 'Sa Kaeo': 9,
  'Sakon Nakhon': 18, 'Samut Prakan': 6, 'Samut Sakhon': 3,
  'Samut Songkhram': 3, 'Saraburi': 13, 'Satun': 7, 'Sing Buri': 6,
  'Sisaket': 22, 'Songkhla': 16, 'Sukhothai': 9, 'Suphan Buri': 10,
  'Surat Thani': 19, 'Surin': 17, 'Tak': 9, 'Trang': 10, 'Trat': 7,
  'Ubon Ratchathani': 25, 'Udon Thani': 20, 'Uthai Thani': 8,
  'Uttaradit': 9, 'Yala': 8, 'Yasothon': 9,
};

const _kGeoToProvince = <String, String>{
  'AmnatCharoen': 'Amnat Charoen', 'AngThong': 'Ang Thong',
  'Bangkok': 'Bangkok', 'BuriRam': 'Buriram', 'Chachoengsao': 'Chachoengsao',
  'ChaiNat': 'Chainat', 'Chaiyaphum': 'Chaiyaphum', 'Chanthaburi': 'Chanthaburi',
  'ChiangMai': 'Chiang Mai', 'ChiangRai': 'Chiang Rai', 'ChonBuri': 'Chonburi',
  'Chumphon': 'Chumphon', 'Kalasin': 'Kalasin', 'KamphaengPhet': 'Kamphaeng Phet',
  'Kanchanaburi': 'Kanchanaburi', 'KhonKaen': 'Khon Kaen', 'Krabi': 'Krabi',
  'Lampang': 'Lampang', 'Lamphun': 'Lamphun', 'Loei': 'Loei',
  'LopBuri': 'Lopburi', 'MaeHongSon': 'Mae Hong Son', 'MahaSarakham': 'Maha Sarakham',
  'Mukdahan': 'Mukdahan', 'NakhonNayok': 'Nakhon Nayok', 'NakhonPathom': 'Nakhon Pathom',
  'NakhonPhanom': 'Nakhon Phanom', 'NakhonRatchasima': 'Nakhon Ratchasima',
  'NakhonSawan': 'Nakhon Sawan', 'NakhonSiThammarat': 'Nakhon Si Thammarat',
  'Nan': 'Nan', 'Narathiwat': 'Narathiwat', 'NongBuaLamPhu': 'Nong Bua Lamphu',
  'NongKhai': 'Nong Khai', 'Nonthaburi': 'Nonthaburi', 'PathumThani': 'Pathum Thani',
  'Pattani': 'Pattani', 'Phang-nga': 'Phang Nga', 'Phatthalung': 'Phatthalung',
  'Phayao': 'Phayao', 'Phetchabun': 'Phetchabun', 'Phetchaburi': 'Phetchaburi',
  'Phichit': 'Phichit', 'Phitsanulok': 'Phitsanulok',
  'PhraNakhonSiAyutthaya': 'Phra Nakhon Si Ayutthaya', 'Phrae': 'Phrae',
  'Phuket': 'Phuket', 'PrachinBuri': 'Prachin Buri', 'PrachuapKhiriKhan': 'Prachuap Khiri Khan',
  'Ranong': 'Ranong', 'Ratchaburi': 'Ratchaburi', 'Rayong': 'Rayong',
  'RoiEt': 'Roi Et', 'SaKaeo': 'Sa Kaeo', 'SakonNakhon': 'Sakon Nakhon',
  'SamutPrakan': 'Samut Prakan', 'SamutSakhon': 'Samut Sakhon',
  'SamutSongkhram': 'Samut Songkhram', 'Saraburi': 'Saraburi', 'Satun': 'Satun',
  'SiSaKet': 'Sisaket', 'SingBuri': 'Sing Buri', 'Songkhla': 'Songkhla',
  'Sukhothai': 'Sukhothai', 'SuphanBuri': 'Suphan Buri', 'SuratThani': 'Surat Thani',
  'Surin': 'Surin', 'Tak': 'Tak', 'Trang': 'Trang', 'Trat': 'Trat',
  'UbonRatchathani': 'Ubon Ratchathani', 'UdonThani': 'Udon Thani',
  'UthaiThani': 'Uthai Thani', 'Uttaradit': 'Uttaradit', 'Yala': 'Yala', 'Yasothon': 'Yasothon',
};

const _kMinLon = 97.3436;
const _kMaxLon = 105.6339;
const _kMinLat = 5.6131;
const _kMaxLat = 20.4645;

// ── Colors ─────────────────────────────────────────────────────────────────────

const _kGold1 = Color(0xFFFFD060);
const _kGold2 = Color(0xFFB8860B);
const _kGold3 = Color(0xFFFFF0A0);

// ── Computed stats ─────────────────────────────────────────────────────────────

class _Stats {
  const _Stats({
    required this.visitedProvinces,
    required this.photosByProvince,
    required this.countriesVisited,
  });

  final Set<String> visitedProvinces;
  final Map<String, List<PhotoItem>> photosByProvince;
  final Map<String, Set<String>> countriesVisited;

  factory _Stats.from(List<PhotoItem> photos) {
    final provinces = <String>{};
    final byProvince = <String, List<PhotoItem>>{};
    final countries = <String, Set<String>>{};

    for (final p in photos) {
      if (p.province.isNotEmpty) {
        provinces.add(p.province);
        byProvince.putIfAbsent(p.province, () => []).add(p);
      }
      if (p.country.isNotEmpty && p.province.isNotEmpty) {
        countries.putIfAbsent(p.country, () => {}).add(p.province);
      }
    }
    return _Stats(
      visitedProvinces: provinces,
      photosByProvince: byProvince,
      countriesVisited: countries,
    );
  }
}

// ── Map shapes ─────────────────────────────────────────────────────────────────

class _ProvinceShape {
  const _ProvinceShape(this.provinceName, this.polygons);
  final String provinceName;
  final List<List<Offset>> polygons;
}

final _shapesProvider = FutureProvider<List<_ProvinceShape>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/thailand.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final features = json['features'] as List<dynamic>;
  final shapes = <_ProvinceShape>[];
  for (final feat in features) {
    final geoKey = (feat['properties'] as Map)['CHA_NE'] as String;
    final provinceName = _kGeoToProvince[geoKey];
    if (provinceName == null) continue;
    final geom = feat['geometry'] as Map<String, dynamic>;
    final type = geom['type'] as String;
    final rawCoords = geom['coordinates'] as List<dynamic>;
    List<List<List<double>>> polys;
    if (type == 'Polygon') {
      polys = [
        rawCoords.map<List<double>>((ring) => (ring as List).expand<double>((pt) {
          final p = pt as List;
          return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
        }).toList()).toList(),
      ];
    } else {
      polys = (rawCoords).map<List<List<double>>>((poly) =>
        (poly as List).map<List<double>>((ring) =>
          (ring as List).expand<double>((pt) {
            final p = pt as List;
            return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
          }).toList()
        ).toList()
      ).toList();
    }
    final offsetPolys = <List<Offset>>[];
    for (final poly in polys) {
      for (final ring in poly) {
        final offsets = <Offset>[];
        for (var i = 0; i < ring.length - 1; i += 2) {
          offsets.add(Offset(
            (ring[i] - _kMinLon) / (_kMaxLon - _kMinLon),
            1.0 - (ring[i + 1] - _kMinLat) / (_kMaxLat - _kMinLat),
          ));
        }
        if (offsets.isNotEmpty) offsetPolys.add(offsets);
      }
    }
    shapes.add(_ProvinceShape(provinceName, offsetPolys));
  }
  return shapes;
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class ProvinceScreen extends ConsumerStatefulWidget {
  const ProvinceScreen({super.key});

  @override
  ConsumerState<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends ConsumerState<ProvinceScreen> {
  String _selectedCountry = 'Thailand';
  // Which province card is currently expanded
  String? _expandedProvince;

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryStateProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stats = _Stats.from(gallery.allPhotos);
    final countries = <String>{'Thailand', ...stats.countriesVisited.keys};
    if (!countries.contains(_selectedCountry)) _selectedCountry = 'Thailand';

    final isThailand = _selectedCountry == 'Thailand';
    final visitedInCountry = isThailand
        ? stats.visitedProvinces
        : (stats.countriesVisited[_selectedCountry] ?? {});

    // Sort: visited → alphabetical; unvisited → alphabetical (visited first)
    final allProvinces = isThailand
        ? (_kDistrictCount.keys.toList())
        : (visitedInCountry.toList());
    allProvinces.sort((a, b) {
      final av = visitedInCountry.contains(a) ? 0 : 1;
      final bv = visitedInCountry.contains(b) ? 0 : 1;
      if (av != bv) return av.compareTo(bv);
      return a.compareTo(b);
    });

    final total = allProvinces.length;
    final visitedCount = allProvinces.where((p) => visitedInCountry.contains(p)).length;
    final progress = total == 0 ? 0.0 : visitedCount / total;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              topPad: topPad,
              isDark: isDark,
              visitedCount: visitedCount,
              total: total,
              progress: progress,
              stats: stats,
              selectedCountry: _selectedCountry,
              countries: countries,
              onCountryChanged: (c) => setState(() {
                _selectedCountry = c;
                _expandedProvince = null;
              }),
              visitedSet: visitedInCountry,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: allProvinces.length,
              itemBuilder: (context, i) {
                final name = allProvinces[i];
                final visited = visitedInCountry.contains(name);
                final photos = stats.photosByProvince[name] ?? [];
                final isExpanded = _expandedProvince == name;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProvinceCard(
                    name: name,
                    visited: visited,
                    photos: photos,
                    isExpanded: isExpanded,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _expandedProvince = isExpanded ? null : name;
                    }),
                    onViewAll: visited
                        ? () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProvinceGalleryScreen(provinceName: name),
                              ),
                            )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({
    required this.topPad,
    required this.isDark,
    required this.visitedCount,
    required this.total,
    required this.progress,
    required this.stats,
    required this.selectedCountry,
    required this.countries,
    required this.onCountryChanged,
    required this.visitedSet,
  });

  final double topPad;
  final bool isDark;
  final int visitedCount;
  final int total;
  final double progress;
  final _Stats stats;
  final String selectedCountry;
  final Set<String> countries;
  final ValueChanged<String> onCountryChanged;
  final Set<String> visitedSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shapesAsync = ref.watch(_shapesProvider);
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.38);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements',
            style: GoogleFonts.poppins(
              fontSize: 30, fontWeight: FontWeight.w700,
              color: titleColor, height: 1.1,
            ),
          ),
          Text(
            '$visitedCount of $total provinces visited',
            style: GoogleFonts.poppins(fontSize: 13, color: subtitleColor),
          ),

          // Country pills
          if (countries.length > 1) ...[
            const SizedBox(height: 14),
            _CountrySelector(
              countries: countries,
              selected: selectedCountry,
              onSelected: onCountryChanged,
              stats: stats,
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 20),

          // Map thumbnail + stats card side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedCountry == 'Thailand')
                SizedBox(
                  width: 86,
                  child: shapesAsync.when(
                    loading: () => const SizedBox(height: 154),
                    error: (err, st) => const SizedBox(height: 154),
                    data: (shapes) => _ThailandMap(
                      shapes: shapes,
                      visitedSet: visitedSet,
                      isDark: isDark,
                    ),
                  ),
                ),
              if (selectedCountry == 'Thailand') const SizedBox(width: 12),
              Expanded(
                child: _StatsCard(
                  visitedCount: visitedCount,
                  total: total,
                  progress: progress,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Country Selector ───────────────────────────────────────────────────────────

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({
    required this.countries, required this.selected,
    required this.onSelected, required this.stats, required this.isDark,
  });

  final Set<String> countries;
  final String selected;
  final ValueChanged<String> onSelected;
  final _Stats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sorted = countries.toList()..sort();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = sorted[i];
          final isSel = c == selected;
          final count = stats.countriesVisited[c]?.length ?? 0;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSel ? const LinearGradient(colors: [_kGold2, _kGold1]) : null,
                color: isSel ? null : (isDark ? const Color(0xFF1C1C28) : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                c != 'Thailand' && count > 0 ? '$c · $count' : c,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                  color: isSel ? Colors.black : (isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.55)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Thailand Map ───────────────────────────────────────────────────────────────

class _ThailandMap extends StatelessWidget {
  const _ThailandMap({required this.shapes, required this.visitedSet, required this.isDark});

  final List<_ProvinceShape> shapes;
  final Set<String> visitedSet;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const aspectRatio = (_kMaxLon - _kMinLon) / (_kMaxLat - _kMinLat);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ThailandPainter(shapes: shapes, visitedSet: visitedSet, isDark: isDark),
        ),
      ),
    );
  }
}

class _ThailandPainter extends CustomPainter {
  const _ThailandPainter({required this.shapes, required this.visitedSet, required this.isDark});

  final List<_ProvinceShape> shapes;
  final Set<String> visitedSet;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in shapes) {
      final isVisited = visitedSet.contains(shape.provinceName);
      for (final ring in shape.polygons) {
        if (ring.length < 3) continue;
        final path = Path()
          ..moveTo(ring[0].dx * size.width, ring[0].dy * size.height);
        for (var i = 1; i < ring.length; i++) {
          path.lineTo(ring[i].dx * size.width, ring[i].dy * size.height);
        }
        path.close();

        if (isVisited) {
          canvas.drawPath(path, Paint()
            ..shader = const LinearGradient(
              colors: [_kGold2, _kGold1, _kGold3],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ).createShader(path.getBounds())
            ..style = PaintingStyle.fill);
          canvas.drawPath(path, Paint()
            ..color = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
        } else {
          canvas.drawPath(path, Paint()
            ..color = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill);
          canvas.drawPath(path, Paint()
            ..color = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.11)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ThailandPainter old) =>
      old.visitedSet != visitedSet || old.isDark != isDark;
}

// ── Stats Card ─────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.visitedCount, required this.total,
    required this.progress, required this.isDark,
  });

  final int visitedCount;
  final int total;
  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF141420) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold2.withValues(alpha: 0.35), width: 1),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: _kGold1, size: 16),
              const SizedBox(width: 6),
              _GoldText('Thailand Explorer', fontSize: 12, fontWeight: FontWeight.w600),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _GoldText(
                '${(progress * 100).toStringAsFixed(0)}%',
                fontSize: 32, fontWeight: FontWeight.w700,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$visitedCount / $total',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
              valueColor: const AlwaysStoppedAnimation<Color>(_kGold1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${total - visitedCount} provinces remaining',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Province Card (expandable) ─────────────────────────────────────────────────

class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({
    required this.name,
    required this.visited,
    required this.photos,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
    required this.onViewAll,
  });

  final String name;
  final bool visited;
  final List<PhotoItem> photos;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final cardBg = visited
        ? (isDark
            ? const LinearGradient(colors: [Color(0xFF251C00), Color(0xFF3A2A00), Color(0xFF251C00)])
            : const LinearGradient(colors: [Color(0xFFFFFAEC), Color(0xFFFFF3C0), Color(0xFFFFFAEC)]))
        : null;

    final solidBg = visited
        ? null
        : (isDark ? const Color(0xFF1A1A26) : Colors.white);

    final borderColor = visited
        ? _kGold2.withValues(alpha: isDark ? 0.55 : 0.42)
        : (isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE5E5EA));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: cardBg,
          color: solidBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: visited && isExpanded
              ? [BoxShadow(color: _kGold1.withValues(alpha: isDark ? 0.08 : 0.14), blurRadius: 12, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  // Accent bar
                  if (visited)
                    Container(
                      width: 3,
                      height: 52,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kGold2, _kGold1, _kGold3],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  SizedBox(width: visited ? 12 : 16),

                  // Icon
                  if (visited)
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kGold2, _kGold1]),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                    )
                  else
                    Icon(Icons.lock_outline_rounded, size: 15,
                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15)),

                  const SizedBox(width: 10),

                  // Name
                  Expanded(
                    child: visited && isDark
                        ? _GoldText(name, fontSize: 13, fontWeight: FontWeight.w600)
                        : Text(name, style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: visited ? FontWeight.w600 : FontWeight.w400,
                            color: visited
                                ? (isDark ? null : const Color(0xFF5A3A00))
                                : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.28)),
                          )),
                  ),

                  // Right side: photo count or chevron
                  if (visited)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${photos.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? _kGold1.withValues(alpha: 0.7) : _kGold2,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: visited
                          ? (isDark ? _kGold1.withValues(alpha: 0.6) : _kGold2.withValues(alpha: 0.7))
                          : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),

            // ── Expanded content ──
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _ExpandedContent(
                      name: name,
                      visited: visited,
                      photos: photos,
                      isDark: isDark,
                      onViewAll: onViewAll,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded content ───────────────────────────────────────────────────────────

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.name,
    required this.visited,
    required this.photos,
    required this.isDark,
    required this.onViewAll,
  });

  final String name;
  final bool visited;
  final List<PhotoItem> photos;
  final bool isDark;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    if (!visited) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Icon(Icons.explore_outlined, size: 14,
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2)),
            const SizedBox(width: 6),
            Text(
              'No photos yet — start exploring!',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    // Sort newest first, take up to 5 for thumbnails
    final sorted = [...photos]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final thumbs = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: dividerColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail strip
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    for (final photo in thumbs)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: photo.assetEntity != null
                              ? Image(
                                  image: AssetEntityImageProvider(
                                    photo.assetEntity!,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize.square(150),
                                  ),
                                  width: 72, height: 72,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 72, height: 72,
                                  color: isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE5E5EA),
                                ),
                        ),
                      ),
                    // "+N more" bubble if there are more
                    if (photos.length > 5)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 72, height: 72,
                          color: isDark ? const Color(0xFF2A2040) : const Color(0xFFEEEAFF),
                          child: Center(
                            child: Text(
                              '+${photos.length - 5}',
                              style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF5A50A0),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Footer: photo count + View All button
              Row(
                children: [
                  Text(
                    '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onViewAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kGold2, _kGold1]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Gold gradient text ─────────────────────────────────────────────────────────

class _GoldText extends StatelessWidget {
  const _GoldText(this.text, {required this.fontSize, required this.fontWeight});
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_kGold2, _kGold1, _kGold3, _kGold1],
        stops: [0.0, 0.4, 0.6, 1.0],
      ).createShader(bounds),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: Colors.white),
      ),
    );
  }
}
