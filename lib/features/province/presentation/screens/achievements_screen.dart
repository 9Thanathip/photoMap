import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_map/features/gallery/presentation/providers/gallery_notifier.dart';
import 'package:photo_map/features/map/presentation/screens/province_gallery_screen.dart';
import '../widgets/achievements_stats.dart';
import '../widgets/country_pills.dart';
import '../widgets/gold_text.dart';

const Map<String, int> _kDistrictCount = {
  'Amnat Charoen': 7,
  'Ang Thong': 7,
  'Bangkok': 50,
  'Bueng Kan': 8,
  'Buriram': 23,
  'Chachoengsao': 11,
  'Chainat': 8,
  'Chaiyaphum': 16,
  'Chanthaburi': 10,
  'Chiang Mai': 25,
  'Chiang Rai': 18,
  'Chonburi': 11,
  'Chumphon': 8,
  'Kalasin': 18,
  'Kamphaeng Phet': 11,
  'Kanchanaburi': 13,
  'Khon Kaen': 26,
  'Krabi': 8,
  'Lampang': 13,
  'Lamphun': 8,
  'Loei': 14,
  'Lopburi': 11,
  'Mae Hong Son': 7,
  'Maha Sarakham': 13,
  'Mukdahan': 7,
  'Nakhon Nayok': 4,
  'Nakhon Pathom': 7,
  'Nakhon Phanom': 12,
  'Nakhon Ratchasima': 32,
  'Nakhon Sawan': 15,
  'Nakhon Si Thammarat': 23,
  'Nan': 15,
  'Narathiwat': 13,
  'Nong Bua Lamphu': 6,
  'Nong Khai': 9,
  'Nonthaburi': 6,
  'Pathum Thani': 7,
  'Pattani': 12,
  'Phang Nga': 8,
  'Phatthalung': 11,
  'Phayao': 9,
  'Phetchabun': 11,
  'Phetchaburi': 8,
  'Phichit': 12,
  'Phitsanulok': 9,
  'Phra Nakhon Si Ayutthaya': 16,
  'Phrae': 8,
  'Phuket': 3,
  'Prachin Buri': 7,
  'Prachuap Khiri Khan': 8,
  'Ranong': 5,
  'Ratchaburi': 10,
  'Rayong': 8,
  'Roi Et': 20,
  'Sa Kaeo': 9,
  'Sakon Nakhon': 18,
  'Samut Prakan': 6,
  'Samut Sakhon': 3,
  'Samut Songkhram': 3,
  'Saraburi': 13,
  'Satun': 7,
  'Sing Buri': 6,
  'Sisaket': 22,
  'Songkhla': 16,
  'Sukhothai': 9,
  'Suphan Buri': 10,
  'Surat Thani': 19,
  'Surin': 17,
  'Tak': 9,
  'Trang': 10,
  'Trat': 7,
  'Ubon Ratchathani': 25,
  'Udon Thani': 20,
  'Uthai Thani': 8,
  'Uttaradit': 9,
  'Yala': 8,
  'Yasothon': 9,
};

class ProvinceScreen extends ConsumerStatefulWidget {
  const ProvinceScreen({super.key});
  @override
  ConsumerState<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends ConsumerState<ProvinceScreen> {
  String _country = 'Thailand';

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(galleryStateProvider).allPhotos;
    final topPad = MediaQuery.paddingOf(context).top;
    final dark = context.isDark;

    final stats = AchievementsStats.from(photos);
    final countries = <String>{'Thailand', ...stats.countriesVisited.keys};
    if (!countries.contains(_country)) _country = 'Thailand';

    final visitedSet = _country == 'Thailand'
        ? stats.visitedProvinces
        : (stats.countriesVisited[_country] ?? {});

    final allProvinces =
        (_country == 'Thailand'
              ? _kDistrictCount.keys.toList()
              : visitedSet.toList())
          ..sort((a, b) {
            final diff = (visitedSet.contains(a) ? 0 : 1).compareTo(
              visitedSet.contains(b) ? 0 : 1,
            );
            return diff != 0 ? diff : a.compareTo(b);
          });

    final visitedCount = allProvinces.where(visitedSet.contains).length;
    final total = allProvinces.length;
    final progress = total == 0 ? 0.0 : visitedCount / total;
    final pct = (progress * 100).toStringAsFixed(0);

    // ── Black & white theme ──
    final bgColor = dark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final cardBg = dark ? const Color(0xFF161616) : Colors.white;
    final borderC = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final tp = dark ? Colors.white : const Color(0xFF111111);
    final ts = dark ? Colors.white54 : const Color(0xFF777777);
    final tt = dark ? Colors.white24 : const Color(0xFFBBBBBB);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Text(
                    'Places',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: tp,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$visitedCount of $total provinces explored',
                    style: GoogleFonts.inter(fontSize: 14, color: ts),
                  ),

                  if (countries.length > 1) ...[
                    const SizedBox(height: 16),
                    CountryPills(
                      countries: countries,
                      selected: _country,
                      stats: stats,
                      onSelected: (c) => setState(() => _country = c),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Progress card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderC),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$pct%',
                          style: GoogleFonts.inter(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            color: tp,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$visitedCount / $total provinces',
                          style: GoogleFonts.inter(fontSize: 13, color: ts),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: tt.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(tp),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Province list ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList.builder(
              itemCount: allProvinces.length,
              itemBuilder: (_, i) {
                final name = allProvinces[i];
                final visited = visitedSet.contains(name);
                final count = stats.photosByProvince[name]?.length ?? 0;

                return GestureDetector(
                  onTap: visited
                      ? () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProvinceGalleryScreen(
                              provinceName: name,
                              countryId: '',
                            ),
                          ),
                        )
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: visited ? cardBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: visited ? Border.all(color: borderC) : null,
                    ),
                    child: Row(
                      children: [
                        // Check / empty circle
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: visited ? tp : Colors.transparent,
                            border: visited
                                ? null
                                : Border.all(color: tt, width: 1.5),
                          ),
                          child: visited
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: dark ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: visited
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: visited ? tp : tt,
                            ),
                          ),
                        ),
                        if (visited && count > 0) ...[
                          Text(
                            '$count',
                            style: GoogleFonts.inter(fontSize: 12, color: ts),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: tt,
                          ),
                        ],
                      ],
                    ),
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
