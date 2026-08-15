import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/admin_login_page.dart';
import '../features/dashboard/presentation/admin_dashboard_page.dart';

/// Système visuel « Dunes et Oasis » pour l’administration : sable, argile et palmeraie.
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
          seedColor: const Color(0xFF214A3B),
          primary: const Color(0xFF214A3B),
          onPrimary: Colors.white,
          secondary: const Color(0xFFD58B2D),
          onSecondary: const Color(0xFF30241B),
          tertiary: const Color(0xFFB85E32),
          onTertiary: Colors.white,
          surface: const Color(0xFFFFF7EA),
          onSurface: const Color(0xFF30241B),
          surfaceContainerHighest: const Color(0xFFF4E8D5),
          outline: const Color(0xFFE5D2B4),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7EA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF214A3B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: const Color(0xFFFFFCF7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE5D2B4)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 76,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x33214A3B),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w900
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF214A3B)
                  : const Color(0xFF756452),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF214A3B),
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
