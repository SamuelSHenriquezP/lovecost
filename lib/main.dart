import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';

// ==========================================
// NOTIFICACIONES LOCALES Y PERMISOS
// ==========================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initLocalNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    debugPrint('Error iniciando notificaciones locales: $e');
  }
}

Future<void> requestNotificationPermissions() async {
  try {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  } catch (e) {
    debugPrint('Error solicitando permisos de notificación: $e');
  }
}

Future<void> showLocalNotification(String title, String body) async {
  try {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'nido_notifications_v2',
          'Notificaciones Nido',
          channelDescription: 'Guiños de amor y comentarios en gastos',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  } catch (e) {
    debugPrint('Error mostrando notificación: $e');
  }
}

// ==========================================
// PUNTO DE ENTRADA
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
    await initLocalNotifications();
    await requestNotificationPermissions();
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
// SISTEMA DE DISEÑO — PALETA DE COLORES VIVOS
// ==========================================
const Color kBackgroundColor = Color(0xFFF6F4F0);
const Color kPrimaryColor = Color(0xFF0D9488); // Teal sobrio y elegante
const Color kSecondaryColor = Color(0xFF00897B); // Verde esmeralda vivo
const Color kAccentColor = Color(0xFF6366F1); // Índigo elegante (cero naranja)
const Color kSurfaceColor = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF1E1917);
const Color kTextMuted = Color(0xFF6B6361);
const Color kBorderColor = Color(0xFFE2DDD7);
const Color kDangerColor = Color(0xFFE53935); // Rojo vivo

const Color kExpenseColor = Color(0xFFE53935); // ROJO VIVO para gastos
const Color kIncomeColor = Color(0xFF10B981); // VERDE VIVO para ingresos
const Color kDisponibleColor = Color(
  0xFF334155,
); // Slate sobrio y elegante para Disponible Real

// ==========================================
// MODOS DE USO DE LA APP
// ==========================================
enum NidoUsageMode {
  guest, // Invitado 100% local
  individual, // Usuario logueado como Individuo (Personal)
  couple, // Usuario logueado en Pareja
}

// ==========================================
// STORAGE LOCAL PARA MODO INVITADO
// ==========================================
class LocalGuestStorage {
  static const String _keyExpenses = 'nido_guest_expenses';
  static const String _keyShopping = 'nido_guest_shopping';
  static const String _keySavings = 'nido_guest_savings';
  static const String _keyHistory = 'nido_guest_history';
  static const String _keyBudget = 'nido_guest_budget';
  static const String _keyCategories = 'nido_guest_categories';
  static const String _keyCycleStart = 'nido_guest_cycle_start';

  static Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBudget) ?? 2000.0;
  }

  static Future<void> setBudget(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBudget, val);
  }

  static Future<DateTime> getCycleStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyCycleStart);
    if (str != null) {
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static Future<void> setCycleStartDate(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCycleStart, dt.toIso8601String());
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExpenses);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveExpenses(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExpenses, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> getShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyShopping);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveShoppingList(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopping, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> getSavings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySavings);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveSavings(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavings, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHistory);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveHistory(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHistory, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCategories);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> saveCategories(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategories, jsonEncode(items));
  }
}

// ==========================================
// HELPERS DE FORMATO
// ==========================================
String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  return formatter.format(amount);
}

String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return 'Hoy';
  if (d == yesterday) return 'Ayer';
  return DateFormat('d MMM', 'es').format(date);
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('es_MX');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.tryParse(digitsOnly) ?? 0;
    final newText = _formatter.format(number);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

double parseFormattedAmount(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) return 0.0;
  return double.tryParse(digitsOnly) ?? 0.0;
}

class _SmoothCurrencyText extends StatefulWidget {
  final double value;
  final TextStyle style;

  const _SmoothCurrencyText({required this.value, required this.style});

  @override
  State<_SmoothCurrencyText> createState() => _SmoothCurrencyTextState();
}

class _SmoothCurrencyTextState extends State<_SmoothCurrencyText> {
  late double _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SmoothCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _oldValue, end: widget.value),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          '${val < 0 ? '-' : ''}${formatCurrency(val.abs())}',
          style: widget.style,
        );
      },
    );
  }
}

String _mapFirebaseError(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      default:
        return 'Error de autenticación. Intenta de nuevo.';
    }
  }
  if (e.toString().contains('network')) {
    return 'Sin conexión a internet. Verifica tu red.';
  }
  return 'Algo salió mal. Intenta de nuevo.';
}

class LocalProfilePhoto {
  static const String _prefKey = 'local_profile_photo_path';

  static Future<String?> getPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefKey);
    if (path == null) return null;
    if (!await File(path).exists()) {
      await prefs.remove(_prefKey);
      return null;
    }
    return path;
  }

  static Future<String?> pickAndSave() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, picked.path);
    return picked.path;
  }

  static Future<void> remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

// ==========================================
// MODELOS DE DATOS
// ==========================================
class Expense {
  final String id;
  final String type; // 'expense' o 'income'
  final double amount;
  final String description;
  final String category;
  final String sourceOrDestination;
  final String createdBy;
  final DateTime date;
  final Map<String, String> reactions;

  const Expense({
    required this.id,
    this.type = 'expense',
    required this.amount,
    required this.description,
    required this.category,
    this.sourceOrDestination = 'General',
    required this.createdBy,
    required this.date,
    this.reactions = const {},
  });

  bool get isIncome => type == 'income';

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) => MapEntry(k, v.toString()));

    return Expense(
      id: doc.id,
      type: (data['type'] as String?) ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Otros',
      sourceOrDestination:
          (data['sourceOrDestination'] as String?) ??
          (data['paymentMethod'] as String?) ??
          'General',
      createdBy: (data['createdBy'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: reactions,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> data) {
    final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) => MapEntry(k, v.toString()));

    return Expense(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: (data['type'] as String?) ?? 'expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Otros',
      sourceOrDestination:
          (data['sourceOrDestination'] as String?) ?? 'General',
      createdBy: (data['createdBy'] as String?) ?? 'Invitado',
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      reactions: reactions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'description': description,
    'category': category,
    'sourceOrDestination': sourceOrDestination,
    'createdBy': createdBy,
    'date': date.toIso8601String(),
    'reactions': reactions,
  };
}

class CustomCategory {
  final String id;
  final String name;
  final String emoji;
  final int colorHex;
  final String type;

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.type,
  });

  factory CustomCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomCategory(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Categoría',
      emoji: (data['emoji'] as String?) ?? '🏷️',
      colorHex: (data['colorHex'] as num?)?.toInt() ?? 0xFF00897B,
      type: (data['type'] as String?) ?? 'expense',
    );
  }

  factory CustomCategory.fromJson(Map<String, dynamic> data) {
    return CustomCategory(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (data['name'] as String?) ?? 'Categoría',
      emoji: (data['emoji'] as String?) ?? '🏷️',
      colorHex: (data['colorHex'] as num?)?.toInt() ?? 0xFF00897B,
      type: (data['type'] as String?) ?? 'expense',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'colorHex': colorHex,
    'type': type,
  };
}

class HistoryPeriod {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final String closedBy;
  final DateTime createdAt;

  HistoryPeriod({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.closedBy,
    required this.createdAt,
  });

  factory HistoryPeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HistoryPeriod(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Periodo Pasado',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalIncome: ((data['totalIncome'] as num?) ?? 0.0).toDouble(),
      totalExpense: ((data['totalExpense'] as num?) ?? 0.0).toDouble(),
      balance: ((data['balance'] as num?) ?? 0.0).toDouble(),
      closedBy: (data['closedBy'] as String?) ?? 'Nido',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory HistoryPeriod.fromJson(Map<String, dynamic> data) {
    return HistoryPeriod(
      id:
          (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (data['title'] as String?) ?? 'Periodo Pasado',
      startDate:
          DateTime.tryParse(data['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(data['endDate'] as String? ?? '') ?? DateTime.now(),
      totalIncome: ((data['totalIncome'] as num?) ?? 0.0).toDouble(),
      totalExpense: ((data['totalExpense'] as num?) ?? 0.0).toDouble(),
      balance: ((data['balance'] as num?) ?? 0.0).toDouble(),
      closedBy: (data['closedBy'] as String?) ?? 'Nido',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'balance': balance,
    'closedBy': closedBy,
    'createdAt': createdAt.toIso8601String(),
  };
}

// ==========================================
// APP PRINCIPAL
// ==========================================
// ==========================================
// DARK MODE NOTIFIER
// ==========================================
final ValueNotifier<ThemeMode> nidoThemeMode = ValueNotifier(ThemeMode.light);

// Dark palette constants
const Color kDarkBackground = Color(0xFF0F172A);
const Color kDarkSurface = Color(0xFF1E293B);
const Color kDarkBorder = Color(0xFF334155);
const Color kDarkTextDark = Color(0xFFF1F5F9);
const Color kDarkTextMuted = Color(0xFF94A3B8);

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

// ==========================================
// SPLASH SCREEN
// ==========================================
class NidoSplash extends StatefulWidget {
  const NidoSplash({super.key});
  @override
  State<NidoSplash> createState() => _NidoSplashState();
}

class _NidoSplashState extends State<NidoSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _start();
  }

  Future<void> _start() async {
    _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, anim1, anim2) => const AuthGate(),
          transitionsBuilder: (context, anim, anim2, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.3),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/images/nido_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(color: kPrimaryColor),
                      child: const Icon(
                        Icons.favorite,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nido',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: kTextDark,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tus finanzas en armonía 🌿',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ANIMACIONES PREMIUM EN LISTA
// ==========================================
class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedListItem({required this.child, required this.index});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = (widget.index * 50).clamp(0, 350);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ==========================================
// GATES DE FLUJO DE USUARIO
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return PairingGate(userId: snapshot.data!.uid);
        }
        return const AuthScreen();
      },
    );
  }
}

class PairingGate extends StatelessWidget {
  final String userId;
  const PairingGate({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final String? coupleId = userData?['coupleId'] as String?;
          final String? usageModeStr = userData?['usageMode'] as String?;
          final String userName = (userData?['name'] as String?) ?? 'Usuario';

          if (usageModeStr == 'individual') {
            return MainNavigation(
              coupleId: 'personal_$userId',
              userId: userId,
              userName: userName,
              mode: NidoUsageMode.individual,
            );
          }

          if (coupleId != null && coupleId.isNotEmpty) {
            return MainNavigation(
              coupleId: coupleId,
              userId: userId,
              userName: userName,
              mode: NidoUsageMode.couple,
            );
          }
        }
        return PairingScreen(userId: userId);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/nido_icon.png',
                width: 64,
                height: 64,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, size: 48, color: kPrimaryColor),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: kPrimaryColor,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DE AUTENTICACIÓN & MODO INVITADO
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_isRegistering) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'name': name,
              'email': email,
              'coupleId': null,
              'usageMode': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(_mapFirebaseError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continuarComoInvitado() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainNavigation(
          coupleId: 'guest_local',
          userId: 'guest_user',
          userName: 'Invitado',
          mode: NidoUsageMode.guest,
        ),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? kDangerColor : kSecondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/nido_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  decoration: const BoxDecoration(
                                    color: kPrimaryColor,
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nido',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: kTextDark,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tus finanzas en armonía 🌿',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _isRegistering
                          ? Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Tu nombre',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      size: 20,
                                      color: kTextMuted,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Ingresa tu nombre'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: kTextMuted,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Correo no válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: kTextMuted,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: kTextMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa tu contraseña';
                        }
                        if (_isRegistering && v.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: kPrimaryColor,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _isRegistering ? 'Crear Cuenta' : 'Entrar',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        setState(() => _isRegistering = !_isRegistering);
                        _formKey.currentState?.reset();
                      },
                      child: Text(
                        _isRegistering
                            ? '¿Ya tienes cuenta? Inicia Sesión'
                            : '¿No tienes cuenta? Regístrate',
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: kBorderColor)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'O bien',
                            style: TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: kBorderColor)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // BOTÓN CONTINUAR COMO INVITADO
                    ElevatedButton.icon(
                      onPressed: _continuarComoInvitado,
                      icon: const Icon(Icons.person_pin_outlined, size: 20),
                      label: const Text(
                        'Usar como Invitado (100% Local)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSurfaceColor,
                        foregroundColor: kSecondaryColor,
                        elevation: 0,
                        side: const BorderSide(
                          color: kSecondaryColor,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SELECCIÓN DE MODO: PAREJA VS INDIVIDUO (PERSONAL)
// ==========================================
class PairingScreen extends StatefulWidget {
  final String userId;
  const PairingScreen({super.key, required this.userId});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _myInviteCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _generateCode() {
    final random = Random.secure();
    return (random.nextInt(900000) + 100000).toString();
  }

  Future<void> _usarComoIndividuo() async {
    setState(() => _isLoading = true);
    try {
      final personalRef = FirebaseFirestore.instance
          .collection('couples')
          .doc('personal_${widget.userId}');

      await personalRef.set({
        'members': [widget.userId],
        'invite_code': 'PERSONAL',
        'budget_limit': 2000.0,
        'resetDay': 1,
        'resetMode': 'monthly',
        'isIndividual': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
            'coupleId': 'personal_${widget.userId}',
            'usageMode': 'individual',
          });
    } catch (e) {
      _showError('Error al activar modo personal.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearGrupoPareja() async {
    setState(() => _isLoading = true);
    try {
      String code;
      bool isUnique = false;
      do {
        code = _generateCode();
        final check = await FirebaseFirestore.instance
            .collection('couples')
            .where('invite_code', isEqualTo: code)
            .limit(1)
            .get();
        isUnique = check.docs.isEmpty;
      } while (!isUnique);

      final coupleRef = FirebaseFirestore.instance.collection('couples').doc();

      await coupleRef.set({
        'members': [widget.userId],
        'invite_code': code,
        'budget_limit': 2000.0,
        'resetDay': 1,
        'resetMode': 'monthly',
        'isIndividual': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'coupleId': coupleRef.id, 'usageMode': 'couple'});

      if (mounted) {
        setState(() {
          _myInviteCode = code;
        });
      }
    } catch (e) {
      if (mounted) _showError('Error al crear espacio en pareja.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unirseGrupoPareja() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      _showError('El código debe tener exactamente 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('couples')
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showError('Código no encontrado. Verifica e intenta de nuevo.');
        return;
      }

      final coupleDoc = query.docs.first;
      final members = List<String>.from(
        coupleDoc.data()['members'] as List? ?? [],
      );

      if (members.contains(widget.userId)) {
        _showError('Ya perteneces a este espacio.');
        return;
      }

      if (members.length >= 2) {
        _showError('Este espacio en pareja ya tiene dos integrantes.');
        return;
      }

      members.add(widget.userId);
      await coupleDoc.reference.update({'members': members});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'coupleId': coupleDoc.id, 'usageMode': 'couple'});
    } catch (e) {
      if (mounted) _showError('Error al unirse. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kDangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _copyCode() {
    if (_myInviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _myInviteCode!));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Código copiado al portapapeles'),
        backgroundColor: kSecondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Cómo deseas usar Nido?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 20),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const _LoadingScaffold()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Selecciona tu modo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Puedes usar Nido para gestionar tus finanzas personales como individuo o conectar en pareja.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: kTextMuted),
                  ),
                  const SizedBox(height: 32),

                  // OPCIÓN MODO INDIVIDUO PERSONAL
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorderColor, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: kSecondaryColor,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Modo Individuo (Personal)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gestiona tus propios ingresos, gastos y metas personales en la nube.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _usarComoIndividuo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSecondaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Usar como Individuo 👤',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Row(
                    children: [
                      Expanded(child: Divider(color: kBorderColor)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'O EN PAREJA',
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: kBorderColor)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_myInviteCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kPrimaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '¡Espacio en pareja creado! Comparte este código:',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: kTextMuted),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _myInviteCode!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: kTextDark,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: kPrimaryColor,
                            ),
                            label: const Text(
                              'Copiar código',
                              style: TextStyle(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _crearGrupoPareja,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Crear Espacio en Pareja 👥',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: kTextDark,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Código de tu pareja',
                        counterText: '',
                        hintText: '000000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _unirseGrupoPareja,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSurfaceColor,
                        foregroundColor: kPrimaryColor,
                        elevation: 0,
                        side: const BorderSide(
                          color: kPrimaryColor,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Unirse con Código 🔗',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ==========================================
// MODAL DE PERFIL Y COMPLEMENTOS
// ==========================================
Future<void> showProfileModal(
  BuildContext context,
  String userId,
  String coupleId,
  String userName,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProfileBottomSheet(
      userId: userId,
      coupleId: coupleId,
      currentUserName: userName,
    ),
  );
}

void _showSendPingModalGlobal(
  BuildContext context,
  String coupleId,
  String userName,
) {
  final pings = [
    '❤️ Te quiero mucho',
    '☕ ¿Un cafecito juntos?',
    '🥰 Te extraño mi amor',
    '🍕 ¿Qué cenamos hoy?',
    '✈️ Pensando en nuestras vacaciones',
    '🤗 Un abrazo apretado',
    '🥂 ¡Salud por nuestro nido!',
    '🌹 Gracias por estar a mi lado',
  ];

  final customPingController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: kSurfaceColor,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Enviar Guiño de Amor 💕',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecciona un mensaje rápido o escribe tu guiño personalizado:',
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pings
                  .map(
                    (p) => ActionChip(
                      avatar: const Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: kPrimaryColor,
                      ),
                      label: Text(
                        p,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      backgroundColor: kBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: kBorderColor),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await FirebaseFirestore.instance
                            .collection('couples')
                            .doc(coupleId)
                            .collection('pings')
                            .add({
                              'message': p,
                              'createdBy': userName,
                              'date': Timestamp.now(),
                            });
                        HapticFeedback.mediumImpact();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✨ Guiño enviado: $p'),
                              backgroundColor: kSecondaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 16),
            const Divider(color: kBorderColor),
            const SizedBox(height: 12),

            const Text(
              '✍️ Escribir guiño personalizado:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customPingController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ej: ¡Te amo mucho! Pasa un hermoso día 💕',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = customPingController.text.trim();
                    if (text.isEmpty) return;

                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(coupleId)
                        .collection('pings')
                        .add({
                          'message': '💌 $text',
                          'createdBy': userName,
                          'date': Timestamp.now(),
                        });
                    HapticFeedback.mediumImpact();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✨ Guiño enviado: $text'),
                          backgroundColor: kSecondaryColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  ).whenComplete(customPingController.dispose);
}

class _ProfileBottomSheet extends StatefulWidget {
  final String userId;
  final String coupleId;
  final String currentUserName;

  const _ProfileBottomSheet({
    required this.userId,
    required this.coupleId,
    required this.currentUserName,
  });

  @override
  State<_ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<_ProfileBottomSheet> {
  final _aliasController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedEmoji = '🦊';
  bool _isSaving = false;
  bool _loaded = false;
  String? _localPhotoPath;

  static const List<String> _emojis = [
    '🦊',
    '🌸',
    '🐻',
    '🐰',
    '🐥',
    '☕',
    '🍕',
    '🚀',
    '🐱',
    '🐼',
    '🦁',
    '🥑',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      _localPhotoPath = await LocalProfilePhoto.getPhotoPath();

      if (!widget.coupleId.startsWith('guest')) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _aliasController.text =
              (data['name'] as String?) ?? widget.currentUserName;
          _birthdayController.text = (data['birthday'] as String?) ?? '';
          _noteController.text = (data['statusNote'] as String?) ?? '';
          _selectedEmoji = (data['avatarEmoji'] as String?) ?? '🦊';
        } else {
          _aliasController.text = widget.currentUserName;
        }
      } else {
        _aliasController.text = widget.currentUserName;
      }
    } catch (_) {
      _aliasController.text = widget.currentUserName;
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final path = await LocalProfilePhoto.pickAndSave();
      if (path != null && mounted) {
        setState(() => _localPhotoPath = path);
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la galería'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    await LocalProfilePhoto.remove();
    if (mounted) setState(() => _localPhotoPath = null);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      if (!widget.coupleId.startsWith('guest')) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({
              'name': _aliasController.text.trim().isEmpty
                  ? widget.currentUserName
                  : _aliasController.text.trim(),
              'birthday': _birthdayController.text.trim(),
              'statusNote': _noteController.text.trim(),
              'avatarEmoji': _selectedEmoji,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ Perfil actualizado'),
            backgroundColor: kSecondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar perfil'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _birthdayController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.face_outlined, color: kPrimaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Mi Perfil 🌿',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_loaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: kPrimaryColor),
                ),
              )
            else ...[
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPrimaryColor.withValues(alpha: 0.12),
                              border: Border.all(color: kBorderColor, width: 2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _localPhotoPath != null
                                ? Image.file(
                                    File(_localPhotoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                          child: Text(
                                            _selectedEmoji,
                                            style: const TextStyle(
                                              fontSize: 42,
                                            ),
                                          ),
                                        ),
                                  )
                                : Center(
                                    child: Text(
                                      _selectedEmoji,
                                      style: const TextStyle(fontSize: 42),
                                    ),
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_localPhotoPath != null)
                      TextButton.icon(
                        onPressed: _removePhoto,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: kTextMuted,
                        ),
                        label: const Text(
                          'Quitar foto',
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                        ),
                      )
                    else
                      Text(
                        'Toca para elegir foto de galería',
                        style: TextStyle(
                          fontSize: 11,
                          color: kTextMuted.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Avatar Emoji:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  itemBuilder: (ctx, i) {
                    final em = _emojis[i];
                    final isSel = _selectedEmoji == em;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = em),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? kPrimaryColor.withValues(alpha: 0.15)
                              : kBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? kPrimaryColor : kBorderColor,
                            width: isSel ? 1.8 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(em, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: 'Tu Nombre / Apodo',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: kTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _birthdayController,
                decoration: const InputDecoration(
                  labelText: 'Cumpleaños / Aniversario (Opcional)',
                  hintText: 'Ej: 14 de Febrero',
                  prefixIcon: Icon(
                    Icons.cake_outlined,
                    size: 20,
                    color: kTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Estado o Nota Corta (Opcional)',
                  hintText: 'Ej: ¡Organizando mis finanzas! 💕',
                  prefixIcon: Icon(
                    Icons.edit_note_outlined,
                    size: 20,
                    color: kTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar Mi Perfil',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartnerHeaderCard extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final String inviteCode;
  final NidoUsageMode mode;

  const _PartnerHeaderCard({
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.inviteCode,
    required this.mode,
  });

  @override
  State<_PartnerHeaderCard> createState() => _PartnerHeaderCardState();
}

class _PartnerHeaderCardState extends State<_PartnerHeaderCard> {
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadLocalPhoto();
  }

  Future<void> _loadLocalPhoto() async {
    final path = await LocalProfilePhoto.getPhotoPath();
    if (mounted) setState(() => _localPhotoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_pin_outlined,
                color: kSecondaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Invitado (Local, sin guardado en la nube)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kTextDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tus datos se guardan únicamente en tu dispositivo 📱',
                    style: TextStyle(fontSize: 11, color: kTextMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (widget.mode == NidoUsageMode.individual) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: kSecondaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finanzas de ${widget.userName} 👤',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Modo Personal en la Nube ☁️',
                    style: TextStyle(fontSize: 11, color: kTextMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.person_outline,
                color: kTextMuted,
                size: 22,
              ),
              tooltip: 'Mi Perfil',
              onPressed: () => showProfileModal(
                context,
                widget.userId,
                widget.coupleId,
                widget.userName,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('coupleId', isEqualTo: widget.coupleId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final myDoc = docs.where((d) => d.id == widget.userId).firstOrNull;
        final partnerDoc = docs.where((d) => d.id != widget.userId).firstOrNull;

        final myData = myDoc?.data() as Map<String, dynamic>?;
        final partnerData = partnerDoc?.data() as Map<String, dynamic>?;

        final myEmoji = (myData?['avatarEmoji'] as String?) ?? '🦊';
        final partnerName = (partnerData?['name'] as String?);
        final partnerEmoji = (partnerData?['avatarEmoji'] as String?) ?? '🌸';
        final partnerNote = (partnerData?['statusNote'] as String?);

        final bool isPaired = partnerName != null && partnerName.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                height: 42,
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await showProfileModal(
                          context,
                          widget.userId,
                          widget.coupleId,
                          widget.userName,
                        );
                        _loadLocalPhoto();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: _localPhotoPath != null
                            ? Image.file(
                                File(_localPhotoPath!),
                                fit: BoxFit.cover,
                                width: 38,
                                height: 38,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(
                                      myEmoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                              )
                            : Text(
                                myEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPaired
                              ? kSecondaryColor.withValues(alpha: 0.18)
                              : kBackgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: kSurfaceColor, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isPaired ? partnerEmoji : '❓',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isPaired
                                ? '${widget.userName} & $partnerName'
                                : 'Tú & Tu Pareja',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isPaired
                                ? Colors.green.shade600
                                : Colors.amber.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaired
                          ? (partnerNote != null && partnerNote.isNotEmpty
                                ? partnerNote
                                : 'Conectados en Nido 💚')
                          : 'Esperando que tu pareja se una…',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPaired ? kTextMuted : Colors.amber.shade800,
                        fontWeight: isPaired
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: kPrimaryColor,
                  size: 22,
                ),
                tooltip: 'Enviar Guiño 💕',
                onPressed: () => _showSendPingModalGlobal(
                  context,
                  widget.coupleId,
                  widget.userName,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.person_outline,
                  color: kTextMuted,
                  size: 22,
                ),
                tooltip: 'Mi Perfil 👤',
                onPressed: () async {
                  await showProfileModal(
                    context,
                    widget.userId,
                    widget.coupleId,
                    widget.userName,
                  );
                  _loadLocalPhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// NAVEGACIÓN PRINCIPAL
// ==========================================
class MainNavigation extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;

  const MainNavigation({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    this.mode = NidoUsageMode.couple,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  String? _lastHandledPingId;

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.couple) {
      _listenToLovePings();
    }
  }

  void _listenToLovePings() {
    FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('pings')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) return;
          final doc = snapshot.docs.first;
          if (doc.id == _lastHandledPingId) return;
          _lastHandledPingId = doc.id;

          final data = doc.data();
          final createdBy = (data['createdBy'] as String?) ?? '';
          final message = (data['message'] as String?) ?? '';
          final date = (data['date'] as Timestamp?)?.toDate();

          if (createdBy.isNotEmpty &&
              createdBy != widget.userName &&
              date != null) {
            if (DateTime.now().difference(date).inSeconds < 45) {
              HapticFeedback.heavyImpact();
              showLocalNotification('💕 Guiño de Amor de $createdBy', message);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$createdBy te envió: "$message"',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: kPrimaryColor,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            }
          }
        });
  }

  void _openOptionsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _NidoOptionsMenu(
        coupleId: widget.coupleId,
        userId: widget.userId,
        userName: widget.userName,
        mode: widget.mode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
        userName: widget.userName,
        mode: widget.mode,
        onOpenMenu: _openOptionsMenu,
      ),
      AnalyticsScreen(
        coupleId: widget.coupleId,
        userName: widget.userName,
        mode: widget.mode,
      ),
      ShoppingListScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
        mode: widget.mode,
      ),
      SavingsGoalsScreen(coupleId: widget.coupleId, mode: widget.mode),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorderColor, width: 1.2)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.account_balance_wallet_outlined,
                color: kTextMuted,
              ),
              selectedIcon: Icon(
                Icons.account_balance_wallet,
                color: kPrimaryColor,
              ),
              label: 'Resumen',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: kPrimaryColor),
              label: 'Análisis',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.shopping_bag, color: kPrimaryColor),
              label: 'Compras',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.savings_rounded, color: kPrimaryColor),
              label: 'Ahorros',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MENÚ DE OPCIONES NIDO (SETTINGS & MODO)
// ==========================================
class _NidoOptionsMenu extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;

  const _NidoOptionsMenu({
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.mode,
  });

  @override
  State<_NidoOptionsMenu> createState() => _NidoOptionsMenuState();
}

class _NidoOptionsMenuState extends State<_NidoOptionsMenu> {
  int _resetDay = 1;
  String _resetMode = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadCoupleSettings();
  }

  Future<void> _loadCoupleSettings() async {
    if (widget.mode != NidoUsageMode.guest) {
      final doc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _resetDay = (data['resetDay'] as num?)?.toInt() ?? 1;
            _resetMode = (data['resetMode'] as String?) ?? 'monthly';
          });
        }
      }
    }
  }

  Future<void> _updateResetSettings(int day, String mode) async {
    setState(() {
      _resetDay = day;
      _resetMode = mode;
    });
    if (widget.mode != NidoUsageMode.guest) {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .update({'resetDay': day, 'resetMode': mode});
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _cerrarPeriodoYArchivar() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar y archivar periodo actual?'),
        content: const Text(
          'Esto guardará un resumen completo de los gastos e ingresos actuales en el Histórico de Periodos de Nido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archivar Periodo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      double totalIncome = 0;
      double totalExpense = 0;

      if (widget.mode == NidoUsageMode.guest) {
        final list = await LocalGuestStorage.getExpenses();
        for (var item in list) {
          final isInc = item['type'] == 'income';
          final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
          if (isInc) {
            totalIncome += amt;
          } else {
            totalExpense += amt;
          }
        }

        final periodTitle = _resetMode == 'biweekly'
            ? 'Quincena - ${DateFormat('MMMM yyyy', 'es').format(now).capitalize()}'
            : DateFormat('MMMM yyyy', 'es').format(now).capitalize();

        final historyList = await LocalGuestStorage.getHistory();
        historyList.add(
          HistoryPeriod(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: periodTitle,
            startDate: startOfMonth,
            endDate: now,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            balance: totalIncome - totalExpense,
            closedBy: widget.userName,
            createdAt: now,
          ).toJson(),
        );
        await LocalGuestStorage.saveHistory(historyList);
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('expenses')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .get();

        final expenses = snapshot.docs
            .map((d) => Expense.fromFirestore(d))
            .toList();
        for (var e in expenses) {
          if (e.isIncome) {
            totalIncome += e.amount;
          } else {
            totalExpense += e.amount;
          }
        }

        final periodTitle = _resetMode == 'biweekly'
            ? 'Quincena - ${DateFormat('MMMM yyyy', 'es').format(now).capitalize()}'
            : DateFormat('MMMM yyyy', 'es').format(now).capitalize();

        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('history_periods')
            .add({
              'title': periodTitle,
              'startDate': Timestamp.fromDate(startOfMonth),
              'endDate': Timestamp.fromDate(now),
              'totalIncome': totalIncome,
              'totalExpense': totalExpense,
              'balance': totalIncome - totalExpense,
              'closedBy': widget.userName,
              'createdAt': FieldValue.serverTimestamp(),
            });
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .update({'cycle_start_date': FieldValue.serverTimestamp()});
      }

      if (widget.mode == NidoUsageMode.guest) {
        await LocalGuestStorage.setCycleStartDate(now);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Periodo archivado e iniciado nuevo ciclo'),
            backgroundColor: kSecondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al archivar periodo'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    }
  }

  void _gestionarCategorias() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gestionar Categorías', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.mode == NidoUsageMode.guest 
                ? null 
                : FirebaseFirestore.instance.collection('couples').doc(widget.coupleId).collection('categories').snapshots(),
            builder: (context, snapshot) {
              if (widget.mode == NidoUsageMode.guest) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: LocalGuestStorage.getCategories(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                    final cats = snap.data!.map((e) => CustomCategory.fromJson(e)).toList();
                    if (cats.isEmpty) return const Text('No hay categorías personalizadas', style: TextStyle(color: kTextMuted));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        return ListTile(
                          leading: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          title: Text(cat.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: kDangerColor),
                            onPressed: () async {
                              final rawCats = await LocalGuestStorage.getCategories();
                              rawCats.removeWhere((c) => c['id'] == cat.id);
                              await LocalGuestStorage.saveCategories(rawCats);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _gestionarCategorias();
                            },
                          ),
                        );
                      }
                    );
                  }
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('No hay categorías personalizadas', style: TextStyle(color: kTextMuted));
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final cat = CustomCategory.fromFirestore(docs[index]);
                  return ListTile(
                    leading: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(cat.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: kDangerColor),
                      onPressed: () {
                         FirebaseFirestore.instance.collection('couples').doc(widget.coupleId).collection('categories').doc(cat.id).delete();
                      }
                    ),
                  );
                }
              );
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: kTextDark))),
        ]
      )
    );
  }

  void _crearNuevaCategoria() {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏷️');
    final hexCtrl = TextEditingController();
    int selectedColor = 0xFF00897B;
    String selectedType = 'expense';

    final List<int> colorOptions = [
      0xFF0D9488,
      0xFF00897B,
      0xFF2563EB,
      0xFF6366F1,
      0xFF9333EA,
      0xFFDB2777,
      0xFF059669,
      0xFF475569,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: kSurfaceColor,
          title: const Text(
            'Nueva Categoría Personalizada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej: Mascotas, Cine)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: emojiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Emoji (ej: 🐶)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: hexCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Color Hex (Opcional)',
                          hintText: 'ej: FF5733',
                          prefixText: '#',
                        ),
                        maxLength: 6,
                        onChanged: (val) {
                          if (val.length == 6) {
                            final parsed = int.tryParse(val, radix: 16);
                            if (parsed != null) {
                              setDialogState(() => selectedColor = 0xFF000000 | parsed);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('➖ Gasto'),
                      selected: selectedType == 'expense',
                      selectedColor: kExpenseColor,
                      labelStyle: TextStyle(
                        color: selectedType == 'expense'
                            ? Colors.white
                            : kTextDark,
                      ),
                      onSelected: (_) =>
                          setDialogState(() => selectedType = 'expense'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('➕ Ingreso'),
                      selected: selectedType == 'income',
                      selectedColor: kIncomeColor,
                      labelStyle: TextStyle(
                        color: selectedType == 'income'
                            ? Colors.white
                            : kTextDark,
                      ),
                      onSelected: (_) =>
                          setDialogState(() => selectedType = 'income'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color identificador (Predefinidos):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kTextMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () {
                        hexCtrl.clear();
                        setDialogState(() => selectedColor = c);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: kTextDark, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final emoji = emojiCtrl.text.trim();
                if (name.isNotEmpty) {
                  if (widget.mode == NidoUsageMode.guest) {
                    final cats = await LocalGuestStorage.getCategories();
                    cats.add(
                      CustomCategory(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        emoji: emoji.isEmpty ? '🏷️' : emoji,
                        colorHex: selectedColor,
                        type: selectedType,
                      ).toJson(),
                    );
                    await LocalGuestStorage.saveCategories(cats);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(widget.coupleId)
                        .collection('categories')
                        .add({
                          'name': name,
                          'emoji': emoji.isEmpty ? '🏷️' : emoji,
                          'colorHex': selectedColor,
                          'type': selectedType,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
                nameCtrl.dispose();
                emojiCtrl.dispose();
                hexCtrl.dispose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings_outlined,
                  color: kPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Menú & Ajustes ⚙️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: kPrimaryColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ciclo de Presupuesto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elige cuándo se reinician los montos o comienza la quincena:',
                    style: TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Mensual'),
                        selected: _resetMode == 'monthly',
                        selectedColor: kPrimaryColor,
                        labelStyle: TextStyle(
                          color: _resetMode == 'monthly'
                              ? Colors.white
                              : kTextDark,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            _updateResetSettings(_resetDay, 'monthly'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Quincenal (Día 1 y 16)'),
                        selected: _resetMode == 'biweekly',
                        selectedColor: kPrimaryColor,
                        labelStyle: TextStyle(
                          color: _resetMode == 'biweekly'
                              ? Colors.white
                              : kTextDark,
                          fontSize: 12,
                        ),
                        onSelected: (_) => _updateResetSettings(1, 'biweekly'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: kSecondaryColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Crear Categoría Personalizada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Añade un icono y color a tus categorías',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.add_circle_outline_rounded,
                color: kSecondaryColor,
              ),
              onTap: _crearNuevaCategoria,
            ),
            const Divider(color: kBorderColor, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: kDangerColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Gestionar Categorías',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Elimina categorías que ya no necesites',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
              ),
              onTap: _gestionarCategorias,
            ),
            const Divider(color: kBorderColor, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: kDangerColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Gestionar Categorías',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Elimina categorías que ya no necesites',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
              ),
              onTap: _gestionarCategorias,
            ),
            const Divider(color: kBorderColor, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Histórico de Ciclos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Revisa los balances y periodos anteriores guardados',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(
                      coupleId: widget.coupleId,
                      mode: widget.mode,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: kBorderColor, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              title: const Text(
                'Archivar Periodo y Reiniciar Ciclo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Guarda el balance del periodo y comienza un nuevo ciclo',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kTextMuted,
              ),
              onTap: _cerrarPeriodoYArchivar,
            ),
            const Divider(color: kBorderColor, height: 1),

            ValueListenableBuilder<ThemeMode>(
              valueListenable: nidoThemeMode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: kAccentColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isDark ? 'Modo Oscuro' : 'Modo Claro',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Alterna entre tema claro y oscuro',
                    style: TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: kAccentColor,
                    onChanged: (val) {
                      nidoThemeMode.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                );
              },
            ),
            const Divider(color: kBorderColor, height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_outlined,
                  color: kDangerColor,
                  size: 20,
                ),
              ),
              title: Text(
                widget.mode == NidoUsageMode.guest
                    ? 'Salir del Modo Invitado'
                    : 'Cerrar Sesión',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kDangerColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (widget.mode == NidoUsageMode.guest) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                } else {
                  FirebaseAuth.instance.signOut();
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 1: DASHBOARD DE MOVIMIENTOS
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;
  final NidoUsageMode mode;
  final VoidCallback onOpenMenu;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.mode,
    required this.onOpenMenu,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterType = 'all'; // 'all', 'expense', 'income'
  String _selectedCategoryFilter = 'all';
  bool _disponibleExpanded = true;
  bool _movimientosExpanded = true;

  // ESTADO MODO INVITADO
  List<Expense> _guestExpenses = [];
  double _guestBudget = 2000.0;
  List<CustomCategory> _guestCategories = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestData();
    }
  }

  Future<void> _loadGuestData() async {
    final rawExpenses = await LocalGuestStorage.getExpenses();
    final budget = await LocalGuestStorage.getBudget();
    final rawCats = await LocalGuestStorage.getCategories();
    final cycleStart = await LocalGuestStorage.getCycleStartDate();

    if (mounted) {
      setState(() {
        final parsed = rawExpenses.map((e) => Expense.fromJson(e)).toList();
        _guestExpenses = parsed
            .where((e) => !e.date.isBefore(cycleStart))
            .toList();
        _guestExpenses.sort((a, b) => b.date.compareTo(a.date));
        _guestBudget = budget;
        _guestCategories = rawCats
            .map((c) => CustomCategory.fromJson(c))
            .toList();
      });
    }
  }

  void _openAddExpenseSheet({
    Expense? expenseToEdit,
    List<CustomCategory>? customCategories,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(
        coupleId: widget.coupleId,
        userName: widget.userName,
        mode: widget.mode,
        expenseToEdit: expenseToEdit,
        onGuestRefresh: _loadGuestData,
        customCategories: customCategories ?? _guestCategories,
      ),
    );
  }

  Stream<List<Expense>> _streamExpenses(DateTime cycleStartDate) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('expenses')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cycleStartDate),
        )
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => Expense.fromFirestore(doc))
              .toList();
          items.sort((a, b) => b.date.compareTo(a.date));
          return items;
        });
  }

  Stream<List<CustomCategory>> _streamCustomCategories() {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('categories')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => CustomCategory.fromFirestore(d)).toList(),
        );
  }

  void _showEditBudgetDialog(BuildContext context, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kSurfaceColor,
        title: const Text(
          'Editar límite mensual',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Límite \$',
            prefixIcon: Icon(
              Icons.account_balance_wallet_outlined,
              size: 20,
              color: kTextMuted,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(controller.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  await LocalGuestStorage.setBudget(val);
                  _loadGuestData();
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .update({'budget_limit': val});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              controller.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == NidoUsageMode.guest) {
      return _buildDashboardBody(
        budgetLimit: _guestBudget,
        inviteCode: '',
        members: [widget.userId],
        allTransactions: _guestExpenses,
        customCats: _guestCategories,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .snapshots(),
      builder: (context, coupleSnapshot) {
        if (coupleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final coupleData = coupleSnapshot.data?.data() as Map<String, dynamic>?;
        final double budgetLimit =
            ((coupleData?['budget_limit'] as num?) ?? 2000.0).toDouble();
        final String inviteCode = (coupleData?['invite_code'] as String?) ?? '';
        final members = List<String>.from(
          coupleData?['members'] as List? ?? [],
        );

        final cycleStartTimestamp =
            coupleData?['cycle_start_date'] as Timestamp?;
        final cycleStartDate =
            cycleStartTimestamp?.toDate() ??
            DateTime(DateTime.now().year, DateTime.now().month, 1);

        return StreamBuilder<List<Expense>>(
          stream: _streamExpenses(cycleStartDate),
          builder: (context, expensesSnapshot) {
            final allTransactions = expensesSnapshot.data ?? [];

            return StreamBuilder<List<CustomCategory>>(
              stream: _streamCustomCategories(),
              builder: (context, customCatSnap) {
                final customCats = customCatSnap.data ?? [];
                return _buildDashboardBody(
                  budgetLimit: budgetLimit,
                  inviteCode: inviteCode,
                  members: members,
                  allTransactions: allTransactions,
                  customCats: customCats,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardBody({
    required double budgetLimit,
    required String inviteCode,
    required List<String> members,
    required List<Expense> allTransactions,
    required List<CustomCategory> customCats,
  }) {
    double totalIngresos = 0;
    double totalGastos = 0;

    for (var t in allTransactions) {
      if (t.isIncome) {
        totalIngresos += t.amount;
      } else {
        totalGastos += t.amount;
      }
    }

    final disponibleReal =
        (totalIngresos > 0 ? totalIngresos : budgetLimit) - totalGastos;
    final porcentajeGastado = totalIngresos > 0
        ? (totalGastos / totalIngresos).clamp(0.0, 1.0)
        : (totalGastos / budgetLimit).clamp(0.0, 1.0);

    final filtered = allTransactions.where((t) {
      if (_filterType == 'income' && !t.isIncome) return false;
      if (_filterType == 'expense' && t.isIncome) return false;
      if (_selectedCategoryFilter != 'all' &&
          t.category != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    final waitingForPartner =
        widget.mode == NidoUsageMode.couple && members.length < 2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/nido_icon.png',
                height: 28,
                width: 28,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Nido · ${DateFormat('MMMM', 'es').format(DateTime.now()).capitalize()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              size: 22,
              color: kTextDark,
            ),
            onPressed: widget.onOpenMenu,
            tooltip: 'Menú de opciones',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _PartnerHeaderCard(
                coupleId: widget.coupleId,
                userId: widget.userId,
                userName: widget.userName,
                inviteCode: inviteCode,
                mode: widget.mode,
              ),
            ),
          ),
          if (waitingForPartner && inviteCode.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _InviteCodeCard(inviteCode: inviteCode),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  _disponibleExpanded ? 18 : 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF334155), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: kDisponibleColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(
                          () => _disponibleExpanded = !_disponibleExpanded,
                        );
                        HapticFeedback.selectionClick();
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Disponible Real',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                _showEditBudgetDialog(context, budgetLimit),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Meta: ${formatCurrency(budgetLimit)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_disponibleExpanded)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _SmoothCurrencyText(
                                value: disponibleReal,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Icon(
                            _disponibleExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstCurve: Curves.easeOutCubic,
                      secondCurve: Curves.easeOutCubic,
                      sizeCurve: Curves.easeOutCubic,
                      crossFadeState: _disponibleExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 220),
                      firstChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SmoothCurrencyText(
                              value: disponibleReal,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: disponibleReal < 0
                                    ? const Color(0xFFFF8A80)
                                    : Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TweenAnimationBuilder<double>(
                            key: ValueKey(porcentajeGastado),
                            tween: Tween(begin: 0.0, end: porcentajeGastado),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, child) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.25,
                                ),
                                color: porcentajeGastado >= 0.9
                                    ? const Color(0xFFFF5252)
                                    : porcentajeGastado > 0.75
                                    ? Colors.amber.shade300
                                    : const Color(0xFF6EE7B7),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 16,
                                            color: Color(0xFF6EE7B7),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Ingresos (+)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(totalIngresos),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 16,
                                            color: Color(0xFFFCA5A5),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Gastos (-)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(totalGastos),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(
                            () => _movimientosExpanded = !_movimientosExpanded,
                          );
                          HapticFeedback.selectionClick();
                        },
                        child: Row(
                          children: [
                            Text(
                              'Movimientos${filtered.isNotEmpty ? ' (${filtered.length})' : ''}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _movimientosExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: kTextMuted,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openAddExpenseSheet(customCategories: customCats),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Añadir',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_movimientosExpanded) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor, width: 1.0),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildInlineTypeOption(
                                'Todos',
                                'all',
                                Icons.format_list_bulleted_rounded,
                                kTextMuted,
                              ),
                              const SizedBox(width: 6),
                              _buildInlineTypeOption(
                                'Gastos',
                                'expense',
                                Icons.remove_circle_outline,
                                kExpenseColor,
                              ),
                              const SizedBox(width: 6),
                              _buildInlineTypeOption(
                                'Ingresos',
                                'income',
                                Icons.add_circle_outline,
                                kIncomeColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openCategoryFilterSheet(customCats),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedCategoryFilter != 'all'
                                    ? kPrimaryColor.withValues(alpha: 0.10)
                                    : kBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedCategoryFilter != 'all'
                                      ? kPrimaryColor
                                      : kBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 16,
                                    color: _selectedCategoryFilter != 'all'
                                        ? kPrimaryColor
                                        : kTextMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedCategoryFilter == 'all'
                                          ? 'Filtrar por Categoría: (Todas)'
                                          : 'Categoría: $_selectedCategoryFilter',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedCategoryFilter != 'all'
                                            ? kPrimaryColor
                                            : kTextDark,
                                      ),
                                    ),
                                  ),
                                  if (_selectedCategoryFilter != 'all')
                                    GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedCategoryFilter = 'all',
                                        );
                                        HapticFeedback.selectionClick();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: kDangerColor,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: kTextMuted,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_movimientosExpanded)
            filtered.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: _EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos registrados',
                        subtitle:
                            'Usa "Añadir" para registrar un ingreso o un gasto.',
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final ex = filtered[index];
                        return _AnimatedListItem(
                          index: index,
                          child: _ExpenseCard(
                            expense: ex,
                            coupleId: widget.coupleId,
                            currentUserName: widget.userName,
                            mode: widget.mode,
                            onEdit: () => _openAddExpenseSheet(
                              expenseToEdit: ex,
                              customCategories: customCats,
                            ),
                            onGuestRefresh: _loadGuestData,
                            customCategories: customCats,
                          ),
                        );
                      }, childCount: filtered.length),
                    ),
                  )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildInlineTypeOption(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final isSelected = _filterType == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _filterType = value;
            _selectedCategoryFilter = 'all';
          });
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimaryColor.withValues(alpha: 0.10)
                : kBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kPrimaryColor : kBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? kPrimaryColor : kTextDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategoryFilterSheet(List<CustomCategory> customCats) {
    final defaultExpenseCats = _AddExpenseBottomSheetState
        ._defaultExpenseCategories
        .map((c) => c['name'] as String)
        .toList();
    final defaultIncomeCats = _AddExpenseBottomSheetState
        ._defaultIncomeCategories
        .map((c) => c['name'] as String)
        .toList();

    final customExpenseCats = customCats
        .where((c) => c.type == 'expense')
        .map((c) => c.name)
        .toList();
    final customIncomeCats = customCats
        .where((c) => c.type == 'income')
        .map((c) => c.name)
        .toList();

    final allExpenses = [...defaultExpenseCats, ...customExpenseCats];
    final allIncomes = [...defaultIncomeCats, ...customIncomeCats];

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFilterState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: kPrimaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtrar por Categoría',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedCategoryFilter != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedCategoryFilter = 'all');
                          setFilterState(() {});
                          HapticFeedback.selectionClick();
                        },
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(
                            color: kDangerColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChoiceChip(
                          label: const Text('✨ Todas las categorías'),
                          selected: _selectedCategoryFilter == 'all',
                          selectedColor: kPrimaryColor.withValues(alpha: 0.15),
                          backgroundColor: kBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: _selectedCategoryFilter == 'all'
                                ? kPrimaryColor
                                : kBorderColor,
                            width: _selectedCategoryFilter == 'all' ? 1.5 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedCategoryFilter == 'all'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedCategoryFilter == 'all'
                                ? kPrimaryColor
                                : kTextDark,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategoryFilter = 'all');
                            setFilterState(() {});
                            HapticFeedback.selectionClick();
                          },
                        ),
                        const SizedBox(height: 14),

                        if (_filterType == 'all' ||
                            _filterType == 'expense') ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 14,
                                color: kExpenseColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Categorías de Gastos',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kExpenseColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allExpenses.map((cat) {
                              final isSel = _selectedCategoryFilter == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: kExpenseColor.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundColor: kBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: isSel ? kExpenseColor : kBorderColor,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? kExpenseColor : kTextDark,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedCategoryFilter = cat);
                                  setFilterState(() {});
                                  HapticFeedback.selectionClick();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_filterType == 'all' ||
                            _filterType == 'income') ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 14,
                                color: kIncomeColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Categorías de Ingresos',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kIncomeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allIncomes.map((cat) {
                              final isSel = _selectedCategoryFilter == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: kIncomeColor.withValues(
                                  alpha: 0.15,
                                ),
                                backgroundColor: kBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: isSel ? kIncomeColor : kBorderColor,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel ? kIncomeColor : kTextDark,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedCategoryFilter = cat);
                                  setFilterState(() {});
                                  HapticFeedback.selectionClick();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Aplicar Filtro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// PANTALLA 2: ANÁLISIS
// ==========================================
class AnalyticsScreen extends StatelessWidget {
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;

  const AnalyticsScreen({
    super.key,
    required this.coupleId,
    required this.userName,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == NidoUsageMode.guest) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: LocalGuestStorage.getExpenses(),
        builder: (context, snapshot) {
          final raw = snapshot.data ?? [];
          final transactions = raw.map((e) => Expense.fromJson(e)).toList();
          return _buildAnalyticsContent(transactions);
        },
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('expenses')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final transactions = docs.map((d) => Expense.fromFirestore(d)).toList();

        return _buildAnalyticsContent(transactions);
      },
    );
  }

  Widget _buildAnalyticsContent(List<Expense> transactions) {
    final expensesOnly = transactions.where((t) => !t.isIncome).toList();
    final incomesOnly = transactions.where((t) => t.isIncome).toList();

    final totalIngresos = incomesOnly.fold<double>(
      0,
      (acc, t) => acc + t.amount,
    );
    final totalGastos = expensesOnly.fold<double>(
      0,
      (acc, t) => acc + t.amount,
    );
    final ahorroNeto = totalIngresos - totalGastos;

    final Map<String, double> gastosPorCategoria = {};
    for (var e in expensesOnly) {
      gastosPorCategoria[e.category] =
          (gastosPorCategoria[e.category] ?? 0) + e.amount;
    }

    final sortedCategories = gastosPorCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> ingresosPorMiembro = {};
    for (var i in incomesOnly) {
      final user = i.createdBy.isNotEmpty ? i.createdBy : 'Usuario';
      ingresosPorMiembro[user] = (ingresosPorMiembro[user] ?? 0) + i.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/images/nido_icon.png',
                width: 26,
                height: 26,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.favorite, color: kPrimaryColor, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Nido · Análisis',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _AnimatedListItem(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorderColor, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance Financiero del Mes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile(
                        'Ingresos',
                        formatCurrency(totalIngresos),
                        kIncomeColor,
                      ),
                      _buildMetricTile(
                        'Gastos',
                        formatCurrency(totalGastos),
                        kExpenseColor,
                      ),
                      _buildMetricTile(
                        'Superávit',
                        formatCurrency(ahorroNeto),
                        ahorroNeto >= 0 ? kDisponibleColor : kExpenseColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _AnimatedListItem(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorderColor, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribución de Gastos por Categoría',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sortedCategories.isEmpty)
                    const Text(
                      'Aún no hay gastos registrados este mes.',
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    )
                  else
                    ...sortedCategories.map((entry) {
                      final porcentaje = totalGastos > 0
                          ? (entry.value / totalGastos)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kTextDark,
                                  ),
                                ),
                                Text(
                                  '${formatCurrency(entry.value)} (${(porcentaje * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kTextDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              key: ValueKey(entry.key),
                              tween: Tween(begin: 0.0, end: porcentaje),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) => ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: val,
                                  minHeight: 8,
                                  backgroundColor: kBackgroundColor,
                                  color: kPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _AnimatedListItem(
            index: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorderColor, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aportantes al Fondo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ingresosPorMiembro.isEmpty)
                    const Text(
                      'Aún no se han registrado ingresos este mes.',
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    )
                  else
                    ...ingresosPorMiembro.entries.map((e) {
                      final pct = totalIngresos > 0
                          ? (e.value / totalIngresos)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: kSecondaryColor.withValues(
                                alpha: 0.2,
                              ),
                              child: Text(
                                e.key.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: kSecondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: kTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(e.key),
                                    tween: Tween(begin: 0.0, end: pct),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, val, child) => ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 6,
                                        backgroundColor: kBackgroundColor,
                                        color: kSecondaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${formatCurrency(e.value)} (${(pct * 100).toInt()}%)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kTextDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kTextMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;

  const _InviteCodeCard({required this.inviteCode});

  void _copyCode(BuildContext context) {
    if (inviteCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: inviteCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Código copiado al portapapeles'),
        backgroundColor: kSecondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (inviteCode.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'Comparte este código con tu pareja:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 10),
          Text(
            inviteCode,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kTextDark,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _copyCode(context),
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: kPrimaryColor,
            ),
            label: const Text(
              'Copiar código',
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CARD DE MOVIMIENTO
// ==========================================
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String coupleId;
  final String currentUserName;
  final NidoUsageMode mode;
  final VoidCallback onEdit;
  final VoidCallback? onGuestRefresh;
  final List<CustomCategory> customCategories;

  const _ExpenseCard({
    required this.expense,
    required this.coupleId,
    required this.currentUserName,
    required this.mode,
    required this.onEdit,
    this.onGuestRefresh,
    this.customCategories = const [],
  });

  Color _categoryColor(String cat, bool isIncome) {
    final custom = customCategories.where((c) => c.name == cat).toList();
    if (custom.isNotEmpty) {
      return Color(custom.first.colorHex);
    }
    
    if (isIncome) return kIncomeColor;
    switch (cat) {
      case 'Citas & Salidas':
      case 'Comida':
        return kExpenseColor;
      case 'Supermercado':
        return const Color(0xFF059669);
      case 'Viajes & Escapadas':
        return const Color(0xFF0284C7);
      case 'Servicios & Hogar':
      case 'Hogar':
        return const Color(0xFFEA580C);
      case 'Detalles & Sorpresas':
        return const Color(0xFF9333EA);
      case 'Entretenimiento':
      case 'Suscripciones':
        return const Color(0xFFD97706);
      case 'Ahorro Pareja':
        return const Color(0xFF0D9488);
      case 'Transporte':
        return const Color(0xFF2563EB);
      default:
        return kSecondaryColor;
    }
  }

  String _categoryEmoji(String cat) {
    final custom = customCategories.where((c) => c.name == cat).toList();
    if (custom.isNotEmpty) {
      return custom.first.emoji;
    }

    switch (cat) {
      case 'Sueldo / Nómina':
        return '💵';
      case 'Freelance / Trabajo':
        return '💼';
      case 'Rendimientos':
        return '📈';
      case 'Regalo / Bono':
        return '🎉';
      case 'Ahorro Previo':
        return '🏦';
      case 'Citas & Salidas':
      case 'Comida':
        return '🍷';
      case 'Supermercado':
        return '🛒';
      case 'Viajes & Escapadas':
        return '✈️';
      case 'Servicios & Hogar':
      case 'Hogar':
        return '🏠';
      case 'Detalles & Sorpresas':
        return '🎁';
      case 'Entretenimiento':
      case 'Suscripciones':
        return '🍿';
      case 'Ahorro Pareja':
        return '🐷';
      case 'Transporte':
        return '🚗';
      default:
        return expense.isIncome ? '💰' : '💸';
    }
  }

  void _showReactionPicker(BuildContext context) {
    if (mode == NidoUsageMode.guest) return;

    final reactions = [
      '🥰 ¡Gracias mi amor!',
      '❤️ ¡Anotado!',
      '🍰 ¡Te debo un postre!',
      '🥂 ¡Salud por nosotros!',
      '👏 ¡Buen movimiento!',
    ];
    final noteController = TextEditingController();
    String? selectedReaction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reaccionar a este movimiento 💕',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.createdBy == currentUserName
                      ? 'Deja una nota para recordar este movimiento'
                      : 'Responde al gasto de ${expense.createdBy}',
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reactions.map((r) {
                    final isSelected = selectedReaction == r;
                    return ActionChip(
                      label: Text(
                        r,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? kPrimaryColor.withValues(alpha: 0.15)
                          : kBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? kPrimaryColor : kBorderColor,
                        ),
                      ),
                      onPressed: () =>
                          setModalState(() => selectedReaction = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nota personal (opcional)',
                    hintText:
                        'Ej: Está bien, pero la próxima lo vemos juntos 💬',
                    prefixIcon: Icon(
                      Icons.edit_note_outlined,
                      size: 20,
                      color: kTextMuted,
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final note = noteController.text.trim();
                    if (selectedReaction == null && note.isEmpty) return;

                    final String reactionText = [
                      if (selectedReaction != null) selectedReaction!,
                      if (note.isNotEmpty) note,
                    ].join(' · ');

                    Navigator.pop(ctx);
                    final updatedReactions = Map<String, String>.from(
                      expense.reactions,
                    );
                    updatedReactions[currentUserName] = reactionText;

                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(coupleId)
                        .collection('expenses')
                        .doc(expense.id)
                        .update({'reactions': updatedReactions});

                    showLocalNotification(
                      '💬 Comentario de $currentUserName',
                      'Reaccionó en ${expense.description.isEmpty ? 'movimiento' : expense.description}: "$reactionText"',
                    );

                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Enviar respuesta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(noteController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.isIncome;
    final accentColor = _categoryColor(expense.category, isIncome);
    final initial = expense.createdBy.isNotEmpty
        ? expense.createdBy.substring(0, 1).toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Dismissible(
        key: Key(expense.id),
        direction: DismissDirection.endToStart,
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete_outline,
            color: kDangerColor,
            size: 24,
          ),
        ),
        background: const SizedBox.shrink(),
        confirmDismiss: (_) async {
          bool confirm = false;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: kSurfaceColor,
              title: Text(
                isIncome ? '¿Eliminar ingreso?' : '¿Eliminar gasto?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                expense.description.isEmpty
                    ? 'Esto eliminará el movimiento de ${formatCurrency(expense.amount)}.'
                    : '¿Seguro que quieres eliminar "${expense.description}"?',
                style: const TextStyle(color: kTextMuted, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: kTextMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    confirm = true;
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDangerColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
          return confirm;
        },
        onDismissed: (_) async {
          if (mode == NidoUsageMode.guest) {
            final list = await LocalGuestStorage.getExpenses();
            list.removeWhere((item) => item['id'] == expense.id);
            await LocalGuestStorage.saveExpenses(list);
            if (onGuestRefresh != null) onGuestRefresh!();
          } else {
            await FirebaseFirestore.instance
                .collection('couples')
                .doc(coupleId)
                .collection('expenses')
                .doc(expense.id)
                .delete();
          }
          HapticFeedback.lightImpact();
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _categoryEmoji(expense.category),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.description.isEmpty
                                        ? (isIncome
                                              ? 'Ingreso registrado'
                                              : 'Gasto general')
                                        : expense.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kTextDark,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${expense.category} · ${formatDate(expense.date)}',
                                    style: const TextStyle(
                                      color: kTextMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? kIncomeColor.withValues(alpha: 0.12)
                                        : kExpenseColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${isIncome ? '+' : '-'}${formatCurrency(expense.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isIncome
                                          ? kIncomeColor
                                          : kExpenseColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kBackgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 7,
                                    backgroundColor: accentColor,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expense.createdBy,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: kTextMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kBackgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '📍 ${expense.sourceOrDestination}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: kTextMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const Spacer(),

                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: kTextMuted,
                              ),
                              onPressed: onEdit,
                              tooltip: 'Editar movimiento',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (mode == NidoUsageMode.couple) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 16,
                                  color: kAccentColor,
                                ),
                                onPressed: () => _showReactionPicker(context),
                                tooltip: 'Reaccionar',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ],
                        ),

                        if (expense.reactions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: expense.reactions.entries
                                .map(
                                  (e) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 3: LISTA DE COMPRAS
// ==========================================
class ShoppingListScreen extends StatefulWidget {
  final String coupleId;
  final String userId;
  final NidoUsageMode mode;

  const ShoppingListScreen({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.mode,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _itemController = TextEditingController();
  bool _isAdding = false;
  List<Map<String, dynamic>> _guestShopping = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestShopping();
    }
  }

  Future<void> _loadGuestShopping() async {
    final list = await LocalGuestStorage.getShoppingList();
    if (mounted) setState(() => _guestShopping = list);
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      if (widget.mode == NidoUsageMode.guest) {
        _guestShopping.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': text,
          'isBought': false,
          'date': DateTime.now().toIso8601String(),
        });
        await LocalGuestStorage.saveShoppingList(_guestShopping);
        _loadGuestShopping();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .add({
              'name': text,
              'title': text,
              'item': text,
              'isBought': false,
              'date': Timestamp.now(),
              'addedBy': widget.userId,
            });
      }
      _itemController.clear();
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _editarItem(String docId, String currentName) async {
    final editCtrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Modificar Artículo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre del artículo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestShopping.indexWhere(
                    (i) => i['id'] == docId,
                  );
                  if (idx != -1) {
                    _guestShopping[idx]['name'] = newText;
                    await LocalGuestStorage.saveShoppingList(_guestShopping);
                    _loadGuestShopping();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('shopping_list')
                      .doc(docId)
                      .update({
                        'name': newText,
                        'title': newText,
                        'item': newText,
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              editCtrl.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarItem(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar artículo?'),
        content: Text('¿Seguro que quieres borrar "$name" de la lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.mode == NidoUsageMode.guest) {
        _guestShopping.removeWhere((i) => i['id'] == docId);
        await LocalGuestStorage.saveShoppingList(_guestShopping);
        _loadGuestShopping();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .doc(docId)
            .delete();
      }
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _toggleItem(String id, bool currentValue, String name) async {
    if (!currentValue) {
      _preguntarConvertirAGasto(id, name);
    } else {
      if (widget.mode == NidoUsageMode.guest) {
        final idx = _guestShopping.indexWhere((i) => i['id'] == id);
        if (idx != -1) {
          _guestShopping[idx]['isBought'] = false;
          await LocalGuestStorage.saveShoppingList(_guestShopping);
          _loadGuestShopping();
        }
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('shopping_list')
            .doc(id)
            .update({'isBought': false});
      }
    }
  }

  void _preguntarConvertirAGasto(String itemId, String name) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kSurfaceColor,
        title: Text(
          '¿Compraste "$name"?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa el monto para registrarlo automáticamente en gastos.',
              style: TextStyle(fontSize: 13, color: kTextMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto \$',
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (widget.mode == NidoUsageMode.guest) {
                final idx = _guestShopping.indexWhere((i) => i['id'] == itemId);
                if (idx != -1) {
                  _guestShopping[idx]['isBought'] = true;
                  await LocalGuestStorage.saveShoppingList(_guestShopping);
                  _loadGuestShopping();
                }
              } else {
                await FirebaseFirestore.instance
                    .collection('couples')
                    .doc(widget.coupleId)
                    .collection('shopping_list')
                    .doc(itemId)
                    .update({'isBought': true});
              }
              if (ctx.mounted) Navigator.pop(ctx);
              amountController.dispose();
            },
            child: const Text(
              'Solo marcar comprado',
              style: TextStyle(color: kTextMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final expList = await LocalGuestStorage.getExpenses();
                  expList.add(
                    Expense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: val,
                      description: 'Supermercado: $name',
                      category: 'Supermercado',
                      createdBy: 'Invitado',
                      date: DateTime.now(),
                      type: 'expense',
                    ).toJson(),
                  );
                  await LocalGuestStorage.saveExpenses(expList);

                  _guestShopping.removeWhere((i) => i['id'] == itemId);
                  await LocalGuestStorage.saveShoppingList(_guestShopping);
                  _loadGuestShopping();
                } else {
                  final batch = FirebaseFirestore.instance.batch();
                  final expenseRef = FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('expenses')
                      .doc();
                  batch.set(expenseRef, {
                    'amount': val,
                    'description': 'Supermercado: $name',
                    'category': 'Supermercado',
                    'createdBy': widget.userId,
                    'date': Timestamp.now(),
                    'type': 'expense',
                  });
                  final itemRef = FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('shopping_list')
                      .doc(itemId);
                  batch.delete(itemRef);
                  await batch.commit();
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              amountController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Registrar Gasto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Compras')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addItem(),
                    decoration: const InputDecoration(
                      labelText: 'Añadir artículo…',
                      prefixIcon: Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 20,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isAdding ? null : _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(52, 52),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.mode == NidoUsageMode.guest
                ? _buildShoppingListUI(
                    _guestShopping
                        .map(
                          (data) => _ShoppingItemWrapper(
                            id: (data['id'] as String?) ?? '',
                            name: (data['name'] as String?) ?? 'Artículo',
                            isBought: (data['isBought'] as bool?) ?? false,
                          ),
                        )
                        .toList(),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('couples')
                        .doc(widget.coupleId)
                        .collection('shopping_list')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final items = docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _ShoppingItemWrapper(
                          id: doc.id,
                          name:
                              (data['name'] as String?) ??
                              (data['title'] as String?) ??
                              'Artículo',
                          isBought: (data['isBought'] as bool?) ?? false,
                        );
                      }).toList();

                      return _buildShoppingListUI(items);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingListUI(List<_ShoppingItemWrapper> items) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Lista vacía',
        subtitle: 'Añade los artículos que necesitan comprar.',
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: item.isBought ? kBackgroundColor : kSurfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isBought
                  ? kBorderColor.withValues(alpha: 0.5)
                  : kBorderColor,
              width: 1.0,
            ),
          ),
          child: ListTile(
            title: Text(
              item.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: item.isBought ? TextDecoration.lineThrough : null,
                color: item.isBought ? kTextMuted : kTextDark,
              ),
            ),
            leading: Checkbox(
              value: item.isBought,
              activeColor: kSecondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => _toggleItem(item.id, item.isBought, item.name),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: kTextMuted,
                  ),
                  onPressed: () => _editarItem(item.id, item.name),
                  tooltip: 'Modificar',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: kDangerColor,
                  ),
                  onPressed: () => _eliminarItem(item.id, item.name),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShoppingItemWrapper {
  final String id;
  final String name;
  final bool isBought;

  _ShoppingItemWrapper({
    required this.id,
    required this.name,
    required this.isBought,
  });
}

// ==========================================
// PANTALLA 4: METAS DE AHORRO
// ==========================================
class SavingsGoalsScreen extends StatefulWidget {
  final String coupleId;
  final NidoUsageMode mode;

  const SavingsGoalsScreen({
    super.key,
    required this.coupleId,
    required this.mode,
  });

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<Map<String, dynamic>> _guestSavings = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == NidoUsageMode.guest) {
      _loadGuestSavings();
    }
  }

  Future<void> _loadGuestSavings() async {
    final list = await LocalGuestStorage.getSavings();
    if (mounted) setState(() => _guestSavings = list);
  }

  void _addGoal(BuildContext context) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kSurfaceColor,
        title: const Text(
          'Nueva Meta de Ahorro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Para qué estamos ahorrando?',
                prefixIcon: Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Meta \$',
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = parseFormattedAmount(targetController.text);
              final title = titleController.text.trim();
              if (title.isNotEmpty && target > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  _guestSavings.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': title,
                    'target': target,
                    'current': 0.0,
                  });
                  await LocalGuestStorage.saveSavings(_guestSavings);
                  _loadGuestSavings();
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .add({
                        'title': title,
                        'target': target,
                        'current': 0.0,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              titleController.dispose();
              targetController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Crear Meta'),
          ),
        ],
      ),
    );
  }

  void _editarMeta(
    BuildContext context,
    String goalId,
    String title,
    double target,
    double current,
  ) {
    final titleCtrl = TextEditingController(text: title);
    final targetCtrl = TextEditingController(text: target.toInt().toString());
    final currentCtrl = TextEditingController(text: current.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Modificar Meta de Ahorro',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título de la meta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(labelText: 'Monto objetivo \$'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currentCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo actual ahorrado \$',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newTarget = parseFormattedAmount(targetCtrl.text);
              final newCurrent = parseFormattedAmount(currentCtrl.text);

              if (newTitle.isNotEmpty && newTarget > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestSavings.indexWhere(
                    (s) => s['id'] == goalId,
                  );
                  if (idx != -1) {
                    _guestSavings[idx]['title'] = newTitle;
                    _guestSavings[idx]['target'] = newTarget;
                    _guestSavings[idx]['current'] = newCurrent;
                    await LocalGuestStorage.saveSavings(_guestSavings);
                    _loadGuestSavings();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .doc(goalId)
                      .update({
                        'title': newTitle,
                        'target': newTarget,
                        'current': newCurrent,
                      });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              titleCtrl.dispose();
              targetCtrl.dispose();
              currentCtrl.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _borrarMeta(BuildContext context, String goalId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Borrar meta de ahorro?'),
        content: Text('¿Seguro que deseas borrar "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar Meta'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.mode == NidoUsageMode.guest) {
        _guestSavings.removeWhere((s) => s['id'] == goalId);
        await LocalGuestStorage.saveSavings(_guestSavings);
        _loadGuestSavings();
      } else {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('savings')
            .doc(goalId)
            .delete();
      }
      HapticFeedback.lightImpact();
    }
  }

  void _contribuirAhorro(
    BuildContext context,
    String goalId,
    double currentSavings,
    double target,
  ) {
    final amountController = TextEditingController();
    final remaining = target - currentSavings;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kSurfaceColor,
        title: const Text(
          'Abonar al Ahorro',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faltan ${formatCurrency(remaining)} para la meta.',
              style: const TextStyle(fontSize: 13, color: kTextMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto a abonar \$',
                prefixIcon: Icon(
                  Icons.attach_money,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) {
                if (widget.mode == NidoUsageMode.guest) {
                  final idx = _guestSavings.indexWhere(
                    (s) => s['id'] == goalId,
                  );
                  if (idx != -1) {
                    final old =
                        (_guestSavings[idx]['current'] as num?)?.toDouble() ??
                        0.0;
                    _guestSavings[idx]['current'] = old + val;
                    await LocalGuestStorage.saveSavings(_guestSavings);
                    _loadGuestSavings();
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('savings')
                      .doc(goalId)
                      .update({'current': FieldValue.increment(val)});
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              amountController.dispose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      body: widget.mode == NidoUsageMode.guest
          ? _buildSavingsUI(
              _guestSavings
                  .map(
                    (s) => _SavingsGoalWrapper(
                      id: (s['id'] as String?) ?? '',
                      title: (s['title'] as String?) ?? 'Meta',
                      target: ((s['target'] as num?) ?? 0.0).toDouble(),
                      current: ((s['current'] as num?) ?? 0.0).toDouble(),
                    ),
                  )
                  .toList(),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('couples')
                  .doc(widget.coupleId)
                  .collection('savings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final goals = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _SavingsGoalWrapper(
                    id: doc.id,
                    title: (data['title'] as String?) ?? 'Meta',
                    target: ((data['target'] as num?) ?? 0.0).toDouble(),
                    current: ((data['current'] as num?) ?? 0.0).toDouble(),
                  );
                }).toList();

                return _buildSavingsUI(goals);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context),
        elevation: 0,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSavingsUI(List<_SavingsGoalWrapper> goals) {
    if (goals.isEmpty) {
      return const _EmptyState(
        icon: Icons.savings_outlined,
        title: 'Sin metas aún',
        subtitle: 'Crea tu primera meta de ahorro.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final double progress = goal.target > 0
            ? (goal.current / goal.target).clamp(0.0, 1.0)
            : 0.0;
        final bool isCompleted = goal.target > 0 && goal.current >= goal.target;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCompleted
                ? kSecondaryColor.withValues(alpha: 0.08)
                : kSurfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCompleted
                  ? kSecondaryColor.withValues(alpha: 0.4)
                  : kBorderColor,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✓ Logrado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kSecondaryColor,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: kTextMuted,
                    ),
                    onPressed: () => _editarMeta(
                      context,
                      goal.id,
                      goal.title,
                      goal.target,
                      goal.current,
                    ),
                    tooltip: 'Modificar meta',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: kDangerColor,
                    ),
                    onPressed: () => _borrarMeta(context, goal.id, goal.title),
                    tooltip: 'Borrar meta',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: kBorderColor,
                  color: isCompleted ? kSecondaryColor : kPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${formatCurrency(goal.current)} de ${formatCurrency(goal.target)}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                ],
              ),
              if (!isCompleted) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _contribuirAhorro(
                      context,
                      goal.id,
                      goal.current,
                      goal.target,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Abonar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSurfaceColor,
                      foregroundColor: kPrimaryColor,
                      elevation: 0,
                      side: const BorderSide(color: kPrimaryColor, width: 1.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SavingsGoalWrapper {
  final String id;
  final String title;
  final double target;
  final double current;

  _SavingsGoalWrapper({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
  });
}

// ==========================================
// PANTALLA 5: HISTÓRICO DE PERIODOS
// ==========================================
class HistoryScreen extends StatelessWidget {
  final String coupleId;
  final NidoUsageMode mode;

  const HistoryScreen({super.key, required this.coupleId, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == NidoUsageMode.guest) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: LocalGuestStorage.getHistory(),
        builder: (context, snapshot) {
          final raw = snapshot.data ?? [];
          final periods = raw.map((e) => HistoryPeriod.fromJson(e)).toList();
          return _buildHistoryUI(periods);
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('history_periods')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final periods = docs
            .map((d) => HistoryPeriod.fromFirestore(d))
            .toList();

        return _buildHistoryUI(periods);
      },
    );
  }

  Widget _buildHistoryUI(List<HistoryPeriod> periods) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Periodos')),
      body: periods.isEmpty
          ? const _EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Sin periodos archivados',
              subtitle:
                  'Usa "Archivar Periodo" en el Menú para guardar resúmenes de ciclos pasados.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final isPositive = p.balance >= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kBorderColor, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: kPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPositive ? 'Superávit' : 'Déficit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPositive
                                    ? kIncomeColor
                                    : kExpenseColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ingresos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kTextMuted,
                                ),
                              ),
                              Text(
                                formatCurrency(p.totalIncome),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kIncomeColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gastos',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kTextMuted,
                                ),
                              ),
                              Text(
                                formatCurrency(p.totalExpense),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kExpenseColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Balance Final',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kTextMuted,
                                ),
                              ),
                              Text(
                                formatCurrency(p.balance),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isPositive
                                      ? kIncomeColor
                                      : kExpenseColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// BOTTOM SHEET: AGREGAR O EDITAR MOVIMIENTO
// ==========================================
class AddExpenseBottomSheet extends StatefulWidget {
  final String coupleId;
  final String userName;
  final NidoUsageMode mode;
  final Expense? expenseToEdit;
  final VoidCallback? onGuestRefresh;
  final List<CustomCategory>? customCategories;

  const AddExpenseBottomSheet({
    super.key,
    required this.coupleId,
    required this.userName,
    required this.mode,
    this.expenseToEdit,
    this.onGuestRefresh,
    this.customCategories,
  });

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController(text: 'Cuenta Principal');

  String _transactionType = 'expense';
  String _selectedCategory = 'Citas & Salidas';
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _defaultExpenseCategories = [
    {'name': 'Citas & Salidas', 'icon': Icons.local_bar_outlined},
    {'name': 'Supermercado', 'icon': Icons.shopping_cart_outlined},
    {'name': 'Viajes & Escapadas', 'icon': Icons.flight_outlined},
    {'name': 'Servicios & Hogar', 'icon': Icons.home_outlined},
    {'name': 'Detalles & Sorpresas', 'icon': Icons.card_giftcard_outlined},
    {'name': 'Entretenimiento', 'icon': Icons.movie_outlined},
    {'name': 'Ahorro Pareja', 'icon': Icons.savings_outlined},
    {'name': 'Transporte', 'icon': Icons.directions_car_outlined},
    {'name': 'Otros', 'icon': Icons.more_horiz_outlined},
  ];

  static const List<Map<String, dynamic>> _defaultIncomeCategories = [
    {'name': 'Sueldo / Nómina', 'icon': Icons.attach_money_outlined},
    {'name': 'Freelance / Trabajo', 'icon': Icons.work_outline},
    {'name': 'Rendimientos', 'icon': Icons.trending_up_outlined},
    {'name': 'Regalo / Bono', 'icon': Icons.card_giftcard_outlined},
    {'name': 'Ahorro Previo', 'icon': Icons.account_balance_outlined},
    {'name': 'Otros', 'icon': Icons.more_horiz_outlined},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final ex = widget.expenseToEdit!;
      _amountController.text = ex.amount.toInt().toString();
      _descriptionController.text = ex.description;
      _sourceController.text = ex.sourceOrDestination;
      _transactionType = ex.type;
      _selectedCategory = ex.category;
    }
  }

  List<Map<String, dynamic>> _buildCategoryOptions(bool isIncome) {
    final defaults = isIncome
        ? _defaultIncomeCategories
        : _defaultExpenseCategories;
    final custom = (widget.customCategories ?? [])
        .where((category) => category.type == (isIncome ? 'income' : 'expense'))
        .map(
          (category) => {
            'name': category.name,
            'emoji': category.emoji,
            'icon': Icons.category_outlined,
          },
        )
        .toList();

    final combined = [...defaults, ...custom];
    combined.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return combined;
  }

  String _defaultCategoryName(bool isIncome) {
    final categories = _buildCategoryOptions(isIncome);
    if (categories.isEmpty) {
      return isIncome ? 'Sueldo / Nómina' : 'Citas & Salidas';
    }
    return categories.first['name'] as String;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _guardarMovimiento() async {
    final amount = parseFormattedAmount(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ingresa un monto válido'),
          backgroundColor: kDangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.mode == NidoUsageMode.guest) {
        final list = await LocalGuestStorage.getExpenses();
        final exp = Expense(
          id:
              widget.expenseToEdit?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          type: _transactionType,
          amount: amount,
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          sourceOrDestination: _sourceController.text.trim().isEmpty
              ? 'General'
              : _sourceController.text.trim(),
          createdBy: widget.userName,
          date: widget.expenseToEdit?.date ?? DateTime.now(),
        );

        if (widget.expenseToEdit != null) {
          final idx = list.indexWhere(
            (i) => i['id'] == widget.expenseToEdit!.id,
          );
          if (idx != -1) list[idx] = exp.toJson();
        } else {
          list.add(exp.toJson());
        }
        await LocalGuestStorage.saveExpenses(list);
        if (widget.onGuestRefresh != null) widget.onGuestRefresh!();
      } else {
        final collectionRef = FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .collection('expenses');

        final data = {
          'type': _transactionType,
          'amount': amount,
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'sourceOrDestination': _sourceController.text.trim().isEmpty
              ? 'General'
              : _sourceController.text.trim(),
          'createdBy': widget.userName,
          'date': widget.expenseToEdit != null
              ? Timestamp.fromDate(widget.expenseToEdit!.date)
              : Timestamp.now(),
        };

        if (widget.expenseToEdit != null) {
          await collectionRef.doc(widget.expenseToEdit!.id).update(data);
        } else {
          await collectionRef.add(data);
        }
      }

      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. Intenta de nuevo.'),
            backgroundColor: kDangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final isIncome = _transactionType == 'income';
    final categories = _buildCategoryOptions(isIncome);

    return Container(
      decoration: const BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + keyboardPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _transactionType = 'expense';
                          _selectedCategory = _defaultCategoryName(false);
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isIncome ? kExpenseColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➖ Registrar Gasto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !isIncome ? Colors.white : kTextMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _transactionType = 'income';
                          _selectedCategory = _defaultCategoryName(true);
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isIncome ? kIncomeColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➕ Añadir Ingreso',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isIncome ? Colors.white : kTextMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: isIncome ? kIncomeColor : kExpenseColor,
                letterSpacing: -1.5,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: kBorderColor,
                  letterSpacing: -1.5,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixText: isIncome ? '+ ' : '- ',
                prefixStyle: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? kIncomeColor : kExpenseColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isIncome
                    ? '¿De qué es este ingreso?'
                    : '¿En qué se gastó?',
                prefixIcon: const Icon(
                  Icons.notes_outlined,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _sourceController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isIncome
                    ? 'Origen (ej: Cuenta Nómina, Efectivo)'
                    : 'Método / Cuenta (ej: Tarjeta, Efectivo)',
                prefixIcon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: kTextMuted,
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : kTextDark,
                        ),
                      ),
                      avatar: cat.containsKey('emoji')
                          ? Text(
                              cat['emoji'] as String,
                              style: const TextStyle(fontSize: 14),
                            )
                          : Icon(
                              cat['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.white : kTextMuted,
                            ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(
                          () => _selectedCategory = cat['name'] as String,
                        );
                        HapticFeedback.selectionClick();
                      },
                      selectedColor: isIncome ? kIncomeColor : kExpenseColor,
                      backgroundColor: kSurfaceColor,
                      side: BorderSide(
                        color: isSelected
                            ? (isIncome ? kIncomeColor : kExpenseColor)
                            : kBorderColor,
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _guardarMovimiento,
              style: ElevatedButton.styleFrom(
                backgroundColor: isIncome ? kIncomeColor : kExpenseColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    (isIncome ? kIncomeColor : kExpenseColor).withValues(
                      alpha: 0.5,
                    ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.expenseToEdit != null
                          ? 'Guardar Cambios'
                          : (isIncome ? 'Guardar Ingreso' : 'Registrar Gasto'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET REUTILIZABLE: ESTADO VACÍO
// ==========================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: kPrimaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: kTextMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
