import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_map/features/map/presentation/providers/country_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initialCountryId;

  try {
    await Firebase.initializeApp();
    
    // Load initial country ID as early as possible
    final prefs = await SharedPreferences.getInstance();
    initialCountryId = prefs.getString('current_country_id');

    // Configure Firestore for both default and named instances
    final firestoreSettings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FirebaseFirestore.instance.settings = firestoreSettings;
    
    // Also apply to the 'countries' database instance if it exists
    try {
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'countries',
      ).settings = firestoreSettings;
    } catch (e) {
      debugPrint('Firestore "countries" instance settings failed: $e');
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        initialCountryIdProvider.overrideWithValue(initialCountryId),
      ],
      child: const App(),
    ),
  );
}
