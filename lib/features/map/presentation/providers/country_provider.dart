import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/country_repository.dart';
import '../../domain/models/country.dart';

class CountryState {
  final Country current;
  final List<Country> available;
  final Set<String> downloadedIds;
  final Map<String, double> downloadProgress;
  final String? error;
  final bool loadedFromFirestore;

  const CountryState({
    required this.current,
    this.available = const [],
    this.downloadedIds = const {},
    this.downloadProgress = const {},
    this.error,
    this.loadedFromFirestore = false,
  });

  CountryState copyWith({
    Country? current,
    List<Country>? available,
    Set<String>? downloadedIds,
    Map<String, double>? downloadProgress,
    String? error,
    bool? loadedFromFirestore,
  }) => CountryState(
    current: current ?? this.current,
    available: available ?? this.available,
    downloadedIds: downloadedIds ?? this.downloadedIds,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    error: error,
    loadedFromFirestore: loadedFromFirestore ?? this.loadedFromFirestore,
  );
}

class CountryNotifier extends StateNotifier<CountryState> {
  CountryNotifier()
    : super(const CountryState(
        current: Country.thailand,
        available: [Country.thailand],
        downloadedIds: {'thailand'},
      )) {
    _init();
  }

  final _repo = CountryRepository();
  static const _prefKey = 'current_country_id';

  Future<void> _init() async {
    try {
      debugPrint('[CountryNotifier] fetching countries from firestore...');
      List<Country> remote = [];
      // Retry up to 3x w/ backoff for unavailable/transient errors
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          remote = await _repo.fetchCountries();
          break;
        } catch (e) {
          debugPrint('[CountryNotifier] attempt ${attempt + 1} failed: $e');
          if (attempt == 2) rethrow;
          await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
        }
      }
      debugPrint('[CountryNotifier] fetched ${remote.length} countries: '
          '${remote.map((c) => c.id).join(", ")}');
      final all = [Country.thailand, ...remote];
      final downloaded = <String>{Country.thailand.id};
      for (final c in remote) {
        if (await _repo.isCached(c.id)) downloaded.add(c.id);
      }

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      Country current = state.current;
      if (savedId != null && downloaded.contains(savedId)) {
        final match = all.where((c) => c.id == savedId).toList();
        if (match.isNotEmpty) current = match.first;
      }

      state = state.copyWith(
        current: current,
        available: all,
        downloadedIds: downloaded,
        loadedFromFirestore: true,
      );
    } catch (e, st) {
      debugPrint('[CountryNotifier] fetch failed: $e\n$st');
      state = state.copyWith(error: 'Could not load countries: $e');
    }
  }

  Future<void> selectCountry(Country c) async {
    if (!state.downloadedIds.contains(c.id)) return;
    state = state.copyWith(current: c);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, c.id);
  }

  Future<void> downloadCountry(Country c) async {
    if (c.isBundled) return;
    if (state.downloadProgress.containsKey(c.id)) return;

    state = state.copyWith(
      downloadProgress: {...state.downloadProgress, c.id: 0.0},
    );

    try {
      await _repo.download(
        c,
        onProgress: (p) {
          state = state.copyWith(
            downloadProgress: {...state.downloadProgress, c.id: p},
          );
        },
      );
      final progress = Map<String, double>.from(state.downloadProgress)
        ..remove(c.id);
      state = state.copyWith(
        downloadedIds: {...state.downloadedIds, c.id},
        downloadProgress: progress,
      );
    } catch (e) {
      final progress = Map<String, double>.from(state.downloadProgress)
        ..remove(c.id);
      state = state.copyWith(
        downloadProgress: progress,
        error: 'Download failed: $e',
      );
    }
  }

  Future<void> deleteCountry(Country c) async {
    if (c.isBundled) return;
    await _repo.deleteCache(c.id);
    final ids = Set<String>.from(state.downloadedIds)..remove(c.id);
    Country current = state.current;
    if (current.id == c.id) current = Country.thailand;
    state = state.copyWith(current: current, downloadedIds: ids);
  }

  CountryRepository get repo => _repo;
}

final countryProvider =
    StateNotifierProvider<CountryNotifier, CountryState>((ref) {
  return CountryNotifier();
});
