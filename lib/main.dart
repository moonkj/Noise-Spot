import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// Google Maps API key must be set in ios/Runner/AppDelegate.swift.
/// Supabase credentials live in core/services/supabase_service.dart.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock for iPhone; iPad uses all orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Run the app immediately — Supabase initialises inside OnboardingScreen
  // via supabaseInitProvider (FutureProvider), so the UI is never blocked.
  runApp(const ProviderScope(child: NoiseSpotApp()));
}
