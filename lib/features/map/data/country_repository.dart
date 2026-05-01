import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../domain/models/country.dart';

class CountryRepository {
  /// Dynamically get the firestore instance. 
  /// Tries 'countries' database first, fallbacks to '(default)'.
  FirebaseFirestore get _db {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'countries',
      );
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// Fetch country list from firestore.
  Future<List<Country>> fetchCountries() async {
    // Try collection 'countries'
    final snap = await _db
        .collection('countries')
        .get(const GetOptions(source: Source.server));
    
    // ignore: avoid_print
    print('[CountryRepo] path=${snap.metadata.isFromCache ? "cache" : "server"} '
        'docs=${snap.docs.length} '
        'ids=${snap.docs.map((d) => d.id).toList()}');
    
    for (final d in snap.docs) {
      // ignore: avoid_print
      print('[CountryRepo] doc ${d.id} data=${d.data()}');
    }
    
    return snap.docs.map((d) => Country.fromMap(d.id, d.data())).toList();
  }

  Future<Directory> _cacheDir() async {
    final dir = await getApplicationSupportDirectory();
    final sub = Directory('${dir.path}/countries');
    if (!await sub.exists()) await sub.create(recursive: true);
    return sub;
  }

  File _geoFile(Directory dir, String id) => File('${dir.path}/$id.json');
  File _metaFile(Directory dir, String id) => File('${dir.path}/$id.meta.json');

  Future<bool> isCached(String id) async {
    final dir = await _cacheDir();
    return _geoFile(dir, id).exists();
  }

  Future<int?> cachedVersion(String id) async {
    final dir = await _cacheDir();
    final f = _metaFile(dir, id);
    if (!await f.exists()) return null;
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (data['version'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  /// Download country geojson + persist to disk.
  Future<void> download(Country c, {void Function(double)? onProgress}) async {
    if (c.isBundled) return;

    final res = await http.Client().send(http.Request('GET', Uri.parse(c.url)));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final dir = await _cacheDir();
    final file = _geoFile(dir, c.id);
    final sink = file.openWrite();
    final total = res.contentLength ?? 0;
    int received = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) onProgress(received / total);
    }
    await sink.close();

    await _metaFile(dir, c.id).writeAsString(jsonEncode(c.toJson()));
  }

  /// Load geojson string for country (from asset or disk).
  Future<String> loadGeoJson(Country c) async {
    if (c.isBundled) {
      final assetPath = c.url.replaceFirst('asset://', '');
      return rootBundle.loadString(assetPath);
    }
    final dir = await _cacheDir();
    final file = _geoFile(dir, c.id);
    if (!await file.exists()) {
      throw StateError('Country ${c.id} not downloaded');
    }
    return file.readAsString();
  }

  Future<void> deleteCache(String id) async {
    final dir = await _cacheDir();
    final f = _geoFile(dir, id);
    final m = _metaFile(dir, id);
    if (await f.exists()) await f.delete();
    if (await m.exists()) await m.delete();
  }
}
