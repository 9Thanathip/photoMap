import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

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

// CHA_NE key in thailand.json → display name mapping
const _kNameMap = <String, String>{
  'AmnatCharoen': 'Amnat Charoen', 'AngThong': 'Ang Thong',
  'Bangkok': 'Bangkok', 'BuriRam': 'Buriram',
  'Chachoengsao': 'Chachoengsao', 'ChaiNat': 'Chainat',
  'Chaiyaphum': 'Chaiyaphum', 'Chanthaburi': 'Chanthaburi',
  'ChiangMai': 'Chiang Mai', 'ChiangRai': 'Chiang Rai',
  'ChonBuri': 'Chonburi', 'Chumphon': 'Chumphon',
  'Kalasin': 'Kalasin', 'KamphaengPhet': 'Kamphaeng Phet',
  'Kanchanaburi': 'Kanchanaburi', 'KhonKaen': 'Khon Kaen',
  'Krabi': 'Krabi', 'Lampang': 'Lampang', 'Lamphun': 'Lamphun',
  'Loei': 'Loei', 'LopBuri': 'Lopburi', 'MaeHongSon': 'Mae Hong Son',
  'MahaSarakham': 'Maha Sarakham', 'Mukdahan': 'Mukdahan',
  'NakhonNayok': 'Nakhon Nayok', 'NakhonPathom': 'Nakhon Pathom',
  'NakhonPhanom': 'Nakhon Phanom', 'NakhonRatchasima': 'Nakhon Ratchasima',
  'NakhonSawan': 'Nakhon Sawan', 'NakhonSiThammarat': 'Nakhon Si Thammarat',
  'Nan': 'Nan', 'Narathiwat': 'Narathiwat', 'NongBuaLamPhu': 'Nong Bua Lamphu',
  'NongKhai': 'Nong Khai', 'Nonthaburi': 'Nonthaburi',
  'PathumThani': 'Pathum Thani', 'Pattani': 'Pattani',
  'Phang-nga': 'Phang Nga', 'Phatthalung': 'Phatthalung',
  'Phayao': 'Phayao', 'Phetchabun': 'Phetchabun',
  'Phetchaburi': 'Phetchaburi', 'Phichit': 'Phichit',
  'Phitsanulok': 'Phitsanulok',
  'PhraNakhonSiAyutthaya': 'Phra Nakhon Si Ayutthaya',
  'Phrae': 'Phrae', 'Phuket': 'Phuket', 'PrachinBuri': 'Prachin Buri',
  'PrachuapKhiriKhan': 'Prachuap Khiri Khan', 'Ranong': 'Ranong',
  'Ratchaburi': 'Ratchaburi', 'Rayong': 'Rayong', 'RoiEt': 'Roi Et',
  'SaKaeo': 'Sa Kaeo', 'SakonNakhon': 'Sakon Nakhon',
  'SamutPrakan': 'Samut Prakan', 'SamutSakhon': 'Samut Sakhon',
  'SamutSongkhram': 'Samut Songkhram', 'Saraburi': 'Saraburi',
  'Satun': 'Satun', 'SingBuri': 'Sing Buri', 'SiSaKet': 'Sisaket',
  'Songkhla': 'Songkhla', 'Sukhothai': 'Sukhothai',
  'SuphanBuri': 'Suphan Buri', 'SuratThani': 'Surat Thani',
  'Surin': 'Surin', 'Tak': 'Tak', 'Trang': 'Trang', 'Trat': 'Trat',
  'UbonRatchathani': 'Ubon Ratchathani', 'UdonThani': 'Udon Thani',
  'UthaiThani': 'Uthai Thani', 'Uttaradit': 'Uttaradit',
  'Yala': 'Yala', 'Yasothon': 'Yasothon',
};

const _kFlags = <String, String>{
  'Thailand': '🇹🇭', 'Japan': '🇯🇵', 'South Korea': '🇰🇷',
  'Singapore': '🇸🇬', 'Vietnam': '🇻🇳', 'Indonesia': '🇮🇩',
  'Malaysia': '🇲🇾', 'USA': '🇺🇸', 'UK': '🇬🇧', 'France': '🇫🇷',
  'Germany': '🇩🇪', 'Italy': '🇮🇹', 'Australia': '🇦🇺',
};

// ── Province shape provider ───────────────────────────────────────────────────
// Loads once, cached by Riverpod for the app session.

final _provinceShapesProvider = FutureProvider<Map<String, Path>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/thailand.json');
  final data = json.decode(raw) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>;
  final result = <String, Path>{};

  for (final feature in features) {
    final rawName = (feature['properties'] as Map)['CHA_NE'] as String;
    final displayName = _kNameMap[rawName];
    if (displayName == null) continue;

    final geometry = feature['geometry'] as Map<String, dynamic>;
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // Collect all rings
    final rings = <List<List<double>>>[];
    if (type == 'Polygon') {
      for (final ring in coordinates) {
        rings.add((ring as List).map((p) => [(p as List)[0] as double, p[1] as double]).toList());
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in coordinates) {
        for (final ring in poly as List) {
          rings.add((ring as List).map((p) => [(p as List)[0] as double, p[1] as double]).toList());
        }
      }
    }

    if (rings.isEmpty) continue;

    // Bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final ring in rings) {
      for (final pt in ring) {
        if (pt[0] < minX) minX = pt[0];
        if (pt[0] > maxX) maxX = pt[0];
        if (pt[1] < minY) minY = pt[1];
        if (pt[1] > maxY) maxY = pt[1];
      }
    }

    final w = maxX - minX;
    final h = maxY - minY;
    if (w == 0 || h == 0) continue;

    // Normalize to [0,1]×[0,1] preserving aspect ratio, centered
    final scale = 1.0 / math.max(w, h);
    final offX = (1.0 - w * scale) / 2;
    final offY = (1.0 - h * scale) / 2;

    final path = Path();
    for (final ring in rings) {
      bool first = true;
      for (final pt in ring) {
        final nx = (pt[0] - minX) * scale + offX;
        // Flip Y: GeoJSON is lat (up=north), canvas is down
        final ny = 1.0 - ((pt[1] - minY) * scale + offY);
        if (first) {
          path.moveTo(nx, ny);
          first = false;
        } else {
          path.lineTo(nx, ny);
        }
      }
      path.close();
    }

    result[displayName] = path;
  }

  return result;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ProvinceScreen extends ConsumerStatefulWidget {
  const ProvinceScreen({super.key});
  @override
  ConsumerState<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends ConsumerState<ProvinceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final isDark = theme.brightness == Brightness.dark;
    final gallery = ref.watch(galleryStateProvider);
    final shapesAsync = ref.watch(_provinceShapesProvider);

    final visitedSet = gallery.allPhotos
        .where((p) => p.province.isNotEmpty && p.province != 'Unknown')
        .map((p) => p.province)
        .toSet();
    final total = _kDistrictCount.length;
    final visited = visitedSet.length;
    final pct = total > 0 ? visited / total : 0.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _Header(
            topPad: topPad,
            visited: visited,
            total: total,
            pct: pct,
            isDark: isDark,
          ),
          _TabBar(controller: _tabs, theme: theme),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CountriesTab(gallery: gallery, isDark: isDark),
                _ProvincesTab(
                  gallery: gallery,
                  visitedSet: visitedSet,
                  shapesAsync: shapesAsync,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.topPad,
    required this.visited,
    required this.total,
    required this.pct,
    required this.isDark,
  });
  final double topPad;
  final int visited;
  final int total;
  final double pct;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(40),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Your travel collection',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              _GlobalProgress(pct: pct, isDark: isDark),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  value: '$visited',
                  label: 'Provinces',
                  isActive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderStat(
                  value: '${total - visited}',
                  label: 'Left to go',
                  isActive: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalProgress extends StatelessWidget {
  const _GlobalProgress({required this.pct, required this.isDark});
  final double pct;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD700).withAlpha(15),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: const Color(0xFFFFD700).withAlpha(30),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(pct * 100).toInt()}%',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFB8860B),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label, required this.isActive});
  final String value;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isActive 
          ? theme.colorScheme.primary.withAlpha(8)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive 
            ? theme.colorScheme.primary.withAlpha(20)
            : theme.colorScheme.outlineVariant.withAlpha(40),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(60), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 14),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFD700),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(160),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller, required this.theme});
  final TabController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: theme.colorScheme.primary),
          insets: const EdgeInsets.symmetric(horizontal: 40),
        ),
        tabs: const [Tab(text: 'Countries'), Tab(text: 'Provinces')],
      ),
    );
  }
}

// ── Countries Tab ─────────────────────────────────────────────────────────────

class _CountriesTab extends StatelessWidget {
  const _CountriesTab({required this.gallery, required this.isDark});
  final GalleryState gallery;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCountry = gallery.photosByCountry;
    final countries = byCountry.keys.where((c) => c != 'Unknown').toList()..sort();

    if (countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌍', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text('No countries yet',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Take photos and let the map fill up',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: countries.length,
      separatorBuilder: (_, i) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final country = countries[i];
        final photos = byCountry[country]!;
        final provinces = photos
            .map((p) => p.province)
            .where((p) => p.isNotEmpty && p != 'Unknown')
            .toSet();
        return _CountryCard(
          country: country,
          photoCount: photos.length,
          provinceCount: provinces.length,
          isDark: isDark,
        );
      },
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.country,
    required this.photoCount,
    required this.provinceCount,
    required this.isDark,
  });
  final String country;
  final int photoCount;
  final int provinceCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = _kFlags[country] ?? '🌍';
    final isGold = photoCount >= 20;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isGold 
          ? (isDark ? const Color(0xFF2D2400) : const Color(0xFFFFFDE7))
          : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGold
            ? const Color(0xFFFFD700).withAlpha(isDark ? 80 : 140)
            : theme.colorScheme.outlineVariant.withAlpha(40),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Smaller flag icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGold
                  ? const Color(0xFFFFD700).withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(100),
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isGold && !isDark
                        ? const Color(0xFF6D4C00)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$provinceCount visited',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),

          // Count bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isGold
                  ? const Color(0xFFFFD700).withAlpha(150)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$photoCount',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isGold ? const Color(0xFF5D4037) : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Provinces Tab ─────────────────────────────────────────────────────────────

class _ProvincesTab extends StatelessWidget {
  const _ProvincesTab({
    required this.gallery,
    required this.visitedSet,
    required this.shapesAsync,
    required this.isDark,
  });
  final GalleryState gallery;
  final Set<String> visitedSet;
  final AsyncValue<Map<String, Path>> shapesAsync;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allProvinces = _kDistrictCount.keys.toList()..sort();
    final gold = allProvinces.where((p) => visitedSet.contains(p)).toList();
    final unvisited = allProvinces.where((p) => !visitedSet.contains(p)).toList();

    final shapes = shapesAsync.valueOrNull ?? {};

    return CustomScrollView(
      slivers: [
        // ── Collection summary ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _CollectionHeader(
              collected: gold.length,
              total: allProvinces.length,
              isDark: isDark,
            ),
          ),
        ),

        // ── Gold provinces ──────────────────────────────────────────────
        if (gold.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text('🥇', style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    'Your Collection',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFAA00),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${gold.length} coins',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _GoldCoin(
                  province: gold[i],
                  shape: shapes[gold[i]],
                  isDark: isDark,
                ),
                childCount: gold.length,
              ),
            ),
          ),
        ],

        // ── Undiscovered ────────────────────────────────────────────────
        if (unvisited.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 15, color: theme.colorScheme.outlineVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Undiscovered',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${unvisited.length} remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _LockedCoin(province: unvisited[i], theme: theme),
                childCount: unvisited.length,
              ),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }
}

// ── Collection header ─────────────────────────────────────────────────────────

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.collected,
    required this.total,
    required this.isDark,
  });
  final int collected;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? collected / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha(isDark ? 60 : 100),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Stacked coins visual
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                Positioned(
                  left: 8, bottom: 0,
                  child: _MiniCoin(size: 44, opacity: 0.5),
                ),
                Positioned(
                  left: 4, bottom: 4,
                  child: _MiniCoin(size: 44, opacity: 0.7),
                ),
                Positioned(
                  left: 0, bottom: 8,
                  child: _MiniCoin(size: 44, opacity: 1.0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$collected',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFD700),
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: ' / $total coins',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withAlpha(140)
                              : const Color(0xFF6D4C00).withAlpha(180),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFFFD700).withAlpha(30),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  collected == 0
                      ? 'Start your journey — visit a province!'
                      : collected == total
                          ? '🎉 Thailand conquered! True Legend!'
                          : 'Collect all 77 gold coins',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withAlpha(120)
                        : const Color(0xFF8B6000).withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCoin extends StatelessWidget {
  const _MiniCoin({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFD54F),
            Color(0xFFFFA000),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA000).withAlpha((60 * opacity).toInt()),
            blurRadius: 8,
            offset: const Offset(1, 2),
          ),
        ],
      ),
    );
  }
}

// ── Gold coin ─────────────────────────────────────────────────────────────────

class _GoldCoin extends StatelessWidget {
  const _GoldCoin({
    required this.province,
    required this.shape,
    required this.isDark,
  });
  final String province;
  final Path? shape;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                // 1. Outer Shadow (Soft ground shadow)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 120 : 40),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

                // 2. Beveled Rim (The metallic edge)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFEE58), // Highlight top
                        Color(0xFF8B6000), // Shadow bottom
                      ],
                    ),
                  ),
                ),

                // 3. Inner Face (Slightly recessed simulation)
                Container(
                  margin: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Use a border to simulate the inner shadow of the beveled edge
                    border: Border.all(
                      color: Colors.black.withAlpha(isDark ? 60 : 30),
                      width: 1.5,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD54F),
                        Color(0xFFE6A000),
                        Color(0xFFFFD54F),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                // 4. Subtle Radial Shine Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withAlpha(120),
                          Colors.transparent,
                        ],
                        center: const Alignment(-0.5, -0.5),
                        radius: 0.6,
                      ),
                    ),
                  ),
                ),

                // 5. Province Shape (Raised/Embossed)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: shape != null
                        ? CustomPaint(
                            painter: _ProvincePainter(shape: shape!, isDark: isDark),
                          )
                        : const Center(
                            child: Icon(Icons.stars_rounded, color: Color(0xFF8B6000), size: 28),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          province,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF5D4037),
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Province shape painter ────────────────────────────────────────────────────

class _ProvincePainter extends CustomPainter {
  const _ProvincePainter({required this.shape, required this.isDark});
  final Path shape;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = Matrix4.diagonal3Values(size.width, size.height, 1);
    final scaled = shape.transform(matrix.storage);

    // 1. Drop shadow for the shape (to give height)
    canvas.drawPath(
      scaled.shift(const Offset(1.5, 1.5)),
      Paint()
        ..color = const Color(0xFF5A3E00).withAlpha(180)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    // 2. Shape Edge highlight (top-left)
    canvas.drawPath(
      scaled.shift(const Offset(-0.5, -0.5)),
      Paint()
        ..color = const Color(0xFFFFF9C4).withAlpha(150),
    );

    // 3. Main metallic fill for the shape
    canvas.drawPath(
      scaled,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF176),
            Color(0xFFFFA000),
          ],
        ).createShader(scaled.getBounds()),
    );

    // 4. Subtle stroke for definition
    canvas.drawPath(
      scaled,
      Paint()
        ..color = const Color(0xFF8B6000).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ProvincePainter old) => old.shape != shape;
}

// ── Locked coin ───────────────────────────────────────────────────────────────

class _LockedCoin extends StatelessWidget {
  const _LockedCoin({required this.province, required this.theme});
  final String province;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(60),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          province,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
