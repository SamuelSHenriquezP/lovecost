import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'services/services.dart';
import 'screens/auth_gate.dart';
import 'services/notification_service.dart';

export 'core/theme.dart';
export 'models/models.dart';
export 'services/services.dart';
export 'screens/auth_gate.dart';
export 'screens/main_navigation.dart';
export 'screens/dashboard_screen.dart';
export 'screens/analytics_screen.dart';
export 'screens/shopping_list_screen.dart';
export 'screens/savings_goals_screen.dart';
export 'screens/history_screen.dart';
export 'widgets/partner_header_card.dart';
export 'widgets/expense_widgets.dart';
export 'widgets/common_widgets.dart';

// ==========================================
// PUNTO DE ENTRADA CON PERSISTENCIA Y NOTIFICACIONES
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  Object? initError;
  try {
    await initializeDateFormatting('es_MX', null);
    await initializeDateFormatting('es', null);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Habilitar Persistencia Offline en Firestore para sincronización transparente
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      debugPrint('Aviso: Configuración de persistencia Firestore: $e');
    }

    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();

    // Cargar preferencia persistida de Modo Oscuro
    try {
      final savedTheme = await LocalGuestStorage.getThemeMode();
      nidoThemeMode.value = savedTheme;
    } catch (e) {
      debugPrint('Aviso: No se pudo cargar tema guardado: $e');
    }
  } catch (e) {
    initError = e;
  }

  if (initError != null) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF6F4F0),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE53935),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al iniciar Nido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    initError.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6361),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const NidoApp());
}

// ==========================================
// APP PRINCIPAL
// ==========================================
class NidoApp extends StatelessWidget {
  const NidoApp({super.key});

  ThemeData _buildTheme({required bool dark}) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final bg = dark ? kDarkBackground : kBackgroundColor;
    final surface = dark ? kDarkSurface : kSurfaceColor;
    final border = dark ? kDarkBorder : kBorderColor;
    final textMain = dark ? kDarkTextDark : kTextDark;
    final textMuted = dark ? kDarkTextMuted : kTextMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      textTheme: textTheme,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryColor,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: kPrimaryColor,
        secondary: kSecondaryColor,
        surface: surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDangerColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDangerColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: textMuted, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: kPrimaryColor.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textMain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: nidoThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Nido — Finanzas',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(dark: false),
          darkTheme: _buildTheme(dark: true),
          home: const NidoSplash(),
        );
      },
    );
  }
}
