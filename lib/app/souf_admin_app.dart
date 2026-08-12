import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/admin_login_page.dart';
import '../features/dashboard/presentation/admin_dashboard_page.dart';

class SoufAdminApp extends StatelessWidget {
  const SoufAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Souf 360 Admin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'DZ'),
      supportedLocales: const [Locale('ar', 'DZ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF193F38),
          primary: const Color(0xFF193F38),
          secondary: const Color(0xFFD9A441),
          surface: const Color(0xFFFBF7EF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF7EF),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) {
            return const AdminLoginPage();
          }
          return const AdminDashboardPage();
        },
      ),
    );
  }
}
