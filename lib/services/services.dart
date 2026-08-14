import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static const String _keyThemeMode = 'nido_guest_theme_mode';

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyThemeMode);
    if (str == 'dark') return ThemeMode.dark;
    if (str == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      await prefs.setString(_keyThemeMode, 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString(_keyThemeMode, 'light');
    } else {
      await prefs.remove(_keyThemeMode);
    }
  }

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

class SmoothCurrencyText extends StatefulWidget {
  final double value;
  final TextStyle style;

  const SmoothCurrencyText({super.key, required this.value, required this.style});

  @override
  State<SmoothCurrencyText> createState() => _SmoothCurrencyTextState();
}

class _SmoothCurrencyTextState extends State<SmoothCurrencyText> {
  late double _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant SmoothCurrencyText oldWidget) {
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

String mapFirebaseError(dynamic e) {
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
