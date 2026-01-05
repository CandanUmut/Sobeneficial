import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'routes.dart';
import 'dart:html' as html; // sadece web’te derlenir

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // web için önerilen
    ),
  );

  // (opsiyonel) web’de oauth dönüşündeki hatayı yut, app çakılmasın
  if (kIsWeb) {
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code') || uri.fragment.contains('access_token');
    if (hasCode) {
      try {
        // Kod / token parçalarını Supabase’e verip session’ı set eder
        await Supabase.instance.client.auth.getSessionFromUrl(uri);

        // Adres çubuğunu temizle (history replace)
        html.window.history.replaceState(null, 'BenefiSocial', '/');
      } catch (e) {
        // Hata olursa sadece logla; app çalışmaya devam etsin
        // debugPrint('getSessionFromUrl error: $e');
      }
    }
  }

  runApp(const BenefiApp());
}

class BenefiApp extends StatelessWidget {
  const BenefiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BenefiSocial',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      routerConfig: appRouter,
    );
  }
}
