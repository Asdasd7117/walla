import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  
  await NotificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'خدمات يمن اونلاين',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      primaryColor: const Color(0xFF1E3A8A),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        primary: const Color(0xFF1E3A8A),
        secondary: const Color(0xFFF59E0B),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    ),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar', '')],
    home: const SplashScreen(),
  );
}
