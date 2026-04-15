import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';
import '../widgets/achievements_stats.dart';
import '../widgets/achievements_stats_card.dart';
import '../widgets/country_pills.dart';
import '../widgets/gold_text.dart';
import '../widgets/province_achievement_card.dart';
import '../widgets/thailand_map_thumbnail.dart';

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

class ProvinceScreen extends ConsumerStatefulWidget {
  const ProvinceScreen({super.key});
  @override
  ConsumerState<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends ConsumerState<ProvinceScreen> {
  String _country = 'Thailand';
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(galleryStateProvider).allPhotos;
    final shapes = ref.watch(shapesProvider);
    final topPad = MediaQuery.paddingOf(context).top;

    final stats = AchievementsStats.from(photos);
    final countries = <String>{'Thailand', ...stats.countriesVisited.keys};
    if (!countries.contains(_country)) _country = 'Thailand';

    final visitedSet = _country == 'Thailand'
        ? stats.visitedProvinces
        : (stats.countriesVisited[_country] ?? {});

    final allProvinces = (_country == 'Thailand'
            ? _kDistrictCount.keys.toList()
            : visitedSet.toList())
        ..sort((a, b) {
          final diff = (visitedSet.contains(a) ? 0 : 1)
              .compareTo(visitedSet.contains(b) ? 0 : 1);
          return diff != 0 ? diff : a.compareTo(b);
        });

    final visitedCount = allProvinces.where(visitedSet.contains).length;
    final progress = allProvinces.isEmpty ? 0.0 : visitedCount / allProvinces.length;

    return Scaffold(
      backgroundColor: context.isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.poppins(
                      fontSize: 30, fontWeight: FontWeight.w700,
                      color: context.isDark ? Colors.white : const Color(0xFF1C1C1E),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '$visitedCount of ${allProvinces.length} provinces visited',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: context.dim(0.38, 0.38)),
                  ),
                  if (countries.length > 1) ...[
                    const SizedBox(height: 14),
                    CountryPills(
                      countries: countries,
                      selected: _country,
                      stats: stats,
                      onSelected: (c) => setState(() {
                        _country = c;
                        _expanded = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_country == 'Thailand') ...[
                        SizedBox(
                          width: 86,
                          child: shapes.when(
                            loading: () => const SizedBox(height: 154),
                            error: (err, st) => const SizedBox(height: 154),
                            data: (s) => ThailandMapThumbnail(
                              shapes: s, visitedSet: visitedSet),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: AchievementsStatsCard(
                          visited: visitedCount,
                          total: allProvinces.length,
                          progress: progress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: allProvinces.length,
              itemBuilder: (context, i) {
                final name = allProvinces[i];
                final isExpanded = _expanded == name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ProvinceAchievementCard(
                    name: name,
                    visited: visitedSet.contains(name),
                    photos: stats.photosByProvince[name] ?? [],
                    isExpanded: isExpanded,
                    onTap: () =>
                        setState(() => _expanded = isExpanded ? null : name),
                    onViewAll: visitedSet.contains(name)
                        ? () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ProvinceGalleryScreen(provinceName: name),
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
