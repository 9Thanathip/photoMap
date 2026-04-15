import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gold_text.dart';

const _minLon = 97.3436, _maxLon = 105.6339;
const _minLat = 5.6131, _maxLat = 20.4645;

const _kGeoToProvince = <String, String>{
  'AmnatCharoen': 'Amnat Charoen', 'AngThong': 'Ang Thong', 'Bangkok': 'Bangkok',
  'BuengKan': 'Bueng Kan', 'BuriRam': 'Buriram', 'Chachoengsao': 'Chachoengsao', 'ChaiNat': 'Chainat',
  'Chaiyaphum': 'Chaiyaphum', 'Chanthaburi': 'Chanthaburi', 'ChiangMai': 'Chiang Mai',
  'ChiangRai': 'Chiang Rai', 'ChonBuri': 'Chonburi', 'Chumphon': 'Chumphon',
  'Kalasin': 'Kalasin', 'KamphaengPhet': 'Kamphaeng Phet', 'Kanchanaburi': 'Kanchanaburi',
  'KhonKaen': 'Khon Kaen', 'Krabi': 'Krabi', 'Lampang': 'Lampang', 'Lamphun': 'Lamphun',
  'Loei': 'Loei', 'LopBuri': 'Lopburi', 'MaeHongSon': 'Mae Hong Son',
  'MahaSarakham': 'Maha Sarakham', 'Mukdahan': 'Mukdahan', 'NakhonNayok': 'Nakhon Nayok',
  'NakhonPathom': 'Nakhon Pathom', 'NakhonPhanom': 'Nakhon Phanom',
  'NakhonRatchasima': 'Nakhon Ratchasima', 'NakhonSawan': 'Nakhon Sawan',
  'NakhonSiThammarat': 'Nakhon Si Thammarat', 'Nan': 'Nan', 'Narathiwat': 'Narathiwat',
  'NongBuaLamPhu': 'Nong Bua Lamphu', 'NongKhai': 'Nong Khai', 'Nonthaburi': 'Nonthaburi',
  'PathumThani': 'Pathum Thani', 'Pattani': 'Pattani', 'Phang-nga': 'Phang Nga',
  'Phatthalung': 'Phatthalung', 'Phayao': 'Phayao', 'Phetchabun': 'Phetchabun',
  'Phetchaburi': 'Phetchaburi', 'Phichit': 'Phichit', 'Phitsanulok': 'Phitsanulok',
  'PhraNakhonSiAyutthaya': 'Phra Nakhon Si Ayutthaya', 'Phrae': 'Phrae', 'Phuket': 'Phuket',
  'PrachinBuri': 'Prachin Buri', 'PrachuapKhiriKhan': 'Prachuap Khiri Khan',
  'Ranong': 'Ranong', 'Ratchaburi': 'Ratchaburi', 'Rayong': 'Rayong', 'RoiEt': 'Roi Et',
  'SaKaeo': 'Sa Kaeo', 'SakonNakhon': 'Sakon Nakhon', 'SamutPrakan': 'Samut Prakan',
  'SamutSakhon': 'Samut Sakhon', 'SamutSongkhram': 'Samut Songkhram',
  'Saraburi': 'Saraburi', 'Satun': 'Satun', 'SiSaKet': 'Sisaket', 'SingBuri': 'Sing Buri',
  'Songkhla': 'Songkhla', 'Sukhothai': 'Sukhothai', 'SuphanBuri': 'Suphan Buri',
  'SuratThani': 'Surat Thani', 'Surin': 'Surin', 'Tak': 'Tak', 'Trang': 'Trang',
  'Trat': 'Trat', 'UbonRatchathani': 'Ubon Ratchathani', 'UdonThani': 'Udon Thani',
  'UthaiThani': 'Uthai Thani', 'Uttaradit': 'Uttaradit', 'Yala': 'Yala', 'Yasothon': 'Yasothon',
};

class ThailandShape {
  const ThailandShape(this.name, this.rings);
  final String name;
  final List<List<Offset>> rings;
}

final shapesProvider = FutureProvider<List<ThailandShape>>((ref) async {
  List<double> flatRing(List raw) => raw.expand<double>((pt) {
        final p = pt as List;
        return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
      }).toList();

  List<Offset> toOffsets(List<double> flat) => [
        for (var i = 0; i < flat.length - 1; i += 2)
          Offset(
            (flat[i] - _minLon) / (_maxLon - _minLon),
            1.0 - (flat[i + 1] - _minLat) / (_maxLat - _minLat),
          ),
      ];

  final json = jsonDecode(await rootBundle.loadString('assets/data/thailand.json'))
      as Map<String, dynamic>;

  return [
    for (final feat in json['features'] as List)
      if (_kGeoToProvince[(feat['properties'] as Map)['CHA_NE'] as String] case final name?)
        () {
          final geom = feat['geometry'] as Map<String, dynamic>;
          final coords = geom['coordinates'] as List;
          final rawPolys =
              geom['type'] == 'Polygon' ? [coords] : coords.map((p) => p as List).toList();
          final rings = [
            for (final poly in rawPolys)
              for (final ring in poly)
                toOffsets(flatRing(ring as List))
          ].where((r) => r.length >= 3).toList();
          return ThailandShape(name, rings);
        }(),
  ];
});

class ThailandMapThumbnail extends StatelessWidget {
  const ThailandMapThumbnail({super.key, required this.shapes, required this.visitedSet});

  final List<ThailandShape> shapes;
  final Set<String> visitedSet;

  @override
  Widget build(BuildContext context) {
    const aspect = (_maxLon - _minLon) / (_maxLat - _minLat);
    return AspectRatio(
      aspectRatio: aspect,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MapPainter(shapes, visitedSet, context.isDark),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.shapes, this.visitedSet, this.isDark);

  final List<ThailandShape> shapes;
  final Set<String> visitedSet;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in shapes) {
      final visited = visitedSet.contains(shape.name);
      for (final ring in shape.rings) {
        final path = Path()
          ..moveTo(ring[0].dx * size.width, ring[0].dy * size.height);
        for (var i = 1; i < ring.length; i++) {
          path.lineTo(ring[i].dx * size.width, ring[i].dy * size.height);
        }
        path.close();

        if (visited) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..shader = const LinearGradient(
                  colors: [kGold2, kGold1, kGold3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(path.getBounds()),
          );
        } else {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.08),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = visited ? 0.5 : 0.4
            ..color = visited
                ? (isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.5))
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.11)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.visitedSet != visitedSet || old.isDark != isDark;
}
