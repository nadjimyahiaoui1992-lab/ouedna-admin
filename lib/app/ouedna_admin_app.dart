import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/admin_login_page.dart';
import '../features/dashboard/presentation/admin_dashboard_page.dart';

class OuednaAdminApp extends StatelessWidget {
  const OuednaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ouedna Admin · وادنا',
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
          brightness: Brightness.light,
          seedColor: const Color(0xFF193F38),
          primary: const Color(0xFF193F38),
          onPrimary: Colors.white,
          secondary: const Color(0xFFD9A441),
          surface: const Color(0xFFFFFBF5),
          surfaceContainerHighest: const Color(0xFFF1F5F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF193F38),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2EAE5)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 76,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x22193F38),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w900
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF193F38)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF193F38),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
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
