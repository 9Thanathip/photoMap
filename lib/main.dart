import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    
    // Configure Firestore for both default and named instances
    final firestoreSettings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      // experimentalForceLongPolling: true, // Uncomment if strictly needed for your network
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
  runApp(const ProviderScope(child: App()));
}
