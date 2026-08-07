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
import 'firebase_options.dart';

// ==========================================
// PUNTO DE ENTRADA
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura errores globales de Flutter
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
  } catch (e) {
    initError = e;
  }

  if (initError != null) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Error al iniciar Nido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  initError.toString(),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8C827F)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const NidoApp());
}

// ==========================================
// SISTEMA DE DISEÑO — TOKENS DE COLOR
// ==========================================
const Color kBackgroundColor = Color(0xFFFAF7F2);
const Color kPrimaryColor = Color(0xFFC97A5E);
const Color kSecondaryColor = Color(0xFF7A9E8F);
const Color kAccentColor = Color(0xFFE89874);
const Color kSurfaceColor = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF2C2523);
const Color kTextMuted = Color(0xFF8C827F);
const Color kBorderColor = Color(0xFFEFECE7);
const Color kDangerColor = Color(0xFFE57373);

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

// Extension helper para mayúsculas
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Formateador de texto con puntos de miles (ej. 10000 -> 10.000)
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

// Widget de texto de moneda que anima cambios suavemente sin reiniciar a $0
class _SmoothCurrencyText extends StatefulWidget {
  final double value;
  final TextStyle style;

  const _SmoothCurrencyText({
    required this.value,
    required this.style,
  });

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

// ==========================================
// MENSAJES DE ERROR DE FIREBASE EN ESPAÑOL
// ==========================================
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
  return 'Algo salió mal. Intenta de nuevo.'
;}

// ==========================================
// FOTO DE PERFIL LOCAL (sin Firebase)
// ==========================================
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
// APP PRINCIPAL
// ==========================================
class NidoApp extends StatelessWidget {
  const NidoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      title: 'Nido — Finanzas en Pareja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
        scaffoldBackgroundColor: kBackgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          surface: kSurfaceColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: kBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: kTextDark),
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: kSurfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kBorderColor, width: 1.2),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorderColor, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorderColor, width: 1.2),
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
          labelStyle: const TextStyle(color: kTextMuted, fontSize: 14),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kSurfaceColor,
          indicatorColor: kPrimaryColor.withValues(alpha: 0.12),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextDark,
            ),
          ),
        ),
      ),
      home: const NidoSplash(),
    );
  }
}

// ==========================================
// SPLASH SCREEN LIMPIA Y DIRECTA
// ==========================================
class NidoSplash extends StatefulWidget {
  const NidoSplash({super.key});
  @override
  State<NidoSplash> createState() => _NidoSplashState();
}

class _NidoSplashState extends State<NidoSplash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
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
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
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
                      color: kPrimaryColor.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/images/nido_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(color: kPrimaryColor),
                      child: const Icon(Icons.favorite, size: 48, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nido',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: kTextDark,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Finanzas en pareja ♥',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextMuted,
                  fontWeight: FontWeight.w500,
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
// ANIMACIONES PREMIUM — ITEM ESCALONADO EN LISTA
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
    _slide = Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = (widget.index * 65).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ==========================================
// FAB PULSANTE CON GLOW
// ==========================================
class _PulsingFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final Color glowColor;

  const _PulsingFAB({
    required this.onPressed,
    required this.child,
    required this.color,
    Color? glowColor,
  }) : glowColor = glowColor ?? color;

  @override
  State<_PulsingFAB> createState() => _PulsingFABState();
}

class _PulsingFABState extends State<_PulsingFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 5.0, end: 18.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.45),
                blurRadius: _glow.value,
                spreadRadius: _glow.value * 0.25,
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'main_fab',
            onPressed: () {
              HapticFeedback.mediumImpact();
              widget.onPressed();
            },
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MODELO DE DATOS (MOVIMIENTOS / GASTOS / INGRESOS)
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
      sourceOrDestination: (data['sourceOrDestination'] as String?) ?? (data['paymentMethod'] as String?) ?? 'General',
      createdBy: (data['createdBy'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: reactions,
    );
  }
}

// ==========================================
// GATES DE FLUJO
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
          final String userName =
              (userData?['name'] as String?) ?? 'Usuario';

          if (coupleId != null && coupleId.isNotEmpty) {
            return MainNavigation(
              coupleId: coupleId,
              userId: userId,
              userName: userName,
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
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.favorite,
                  size: 48,
                  color: kPrimaryColor,
                ),
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
// PANTALLA DE AUTENTICACIÓN
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
                    // Logo animado de Nido
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (_, val, child) => Transform.scale(scale: val, child: child),
                      child: Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimaryColor.withValues(alpha: 0.25),
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
                              errorBuilder: (_, __, ___) => Container(
                                decoration: const BoxDecoration(color: kPrimaryColor),
                                child: const Icon(Icons.favorite, size: 44, color: Colors.white),
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
                      'Tu hogar financiero en pareja ♥',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: kTextMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Campo de nombre (solo registro)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _isRegistering
                          ? Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization:
                                      TextCapitalization.words,
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

                    // Email
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

                    // Contraseña
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
                              () => _obscurePassword = !_obscurePassword),
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
                    const SizedBox(height: 32),

                    // Botón principal
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
// PANTALLA DE VINCULACIÓN DE PAREJA
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

  Future<void> _crearGrupo() async {
    setState(() => _isLoading = true);
    try {
      // Generar código único
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

      final coupleRef =
          FirebaseFirestore.instance.collection('couples').doc();

      await coupleRef.set({
        'members': [widget.userId],
        'invite_code': code,
        'budget_limit': 1000.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'coupleId': coupleRef.id});

      if (mounted) {
        setState(() {
          _myInviteCode = code;
        });
      }
    } catch (e) {
      if (mounted) _showError('Error al crear grupo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unirseGrupo() async {
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
      final members =
          List<String>.from(coupleDoc.data()['members'] as List? ?? []);

      if (members.contains(widget.userId)) {
        _showError('Ya perteneces a este grupo.');
        return;
      }

      if (members.length >= 2) {
        _showError('Este grupo ya tiene dos integrantes.');
        return;
      }

      members.add(widget.userId);
      await coupleDoc.reference.update({'members': members});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'coupleId': coupleDoc.id});
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comenzar en pareja'),
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
                  const SizedBox(height: 24),
                  Text(
                    'Empiecen a construir',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea un espacio común o únete si tu pareja ya lo creó.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: kTextMuted),
                  ),
                  const SizedBox(height: 40),

                  // Si ya creó un grupo, mostrar el código
                  if (_myInviteCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kSecondaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '¡Grupo creado! Comparte este código con tu pareja:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextMuted,
                            ),
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
                    const Text(
                      'Esperando que tu pareja se una...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: kTextMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    // Botón crear grupo
                    ElevatedButton(
                      onPressed: _crearGrupo,
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
                        'Crear nuevo espacio compartido',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: kBorderColor)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'O',
                            style: TextStyle(color: kTextMuted, fontSize: 13),
                          ),
                        ),
                        Expanded(child: Divider(color: kBorderColor)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Unirse con código
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _unirseGrupo,
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
                        'Unirse con código',
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
// MODAL DE PERFIL Y CONEXIÓN DE PAREJA
// ==========================================
Future<void> showProfileModal(BuildContext context, String userId, String coupleId, String userName) {
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

void _showSendPingModalGlobal(BuildContext context, String coupleId, String userName) {
  final pings = [
    '❤️ Te quiero mucho',
    '☕ ¿Un cafecito juntos?',
    '🥰 Te extraño mi amor',
    '🍕 ¿Qué cenamos hoy?',
    '✈️ Pensando en nuestras vacaciones',
    '🤗 Un abrazo apretado',
    '🥂 ¡Salud por nuestro nido!',
  ];

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: kSurfaceColor,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: kPrimaryColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Enviar Guiño de Amor 💕',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
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
            'Envia un mensaje instantáneo a la pantalla de tu pareja:',
            style: TextStyle(color: kTextMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pings.map((p) => ActionChip(
              avatar: const Icon(Icons.favorite_rounded, size: 14, color: kPrimaryColor),
              label: Text(p, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
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

  static const List<String> _emojis = ['🦊', '🌸', '🐻', '🐰', '🐥', '☕', '🍕', '🚀', '🐱', '🐼', '🦁', '🥑'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      // Cargar foto local (sin Firebase)
      _localPhotoPath = await LocalProfilePhoto.getPhotoPath();

      // Cargar datos de Firestore (solo una vez al abrir el modal)
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _aliasController.text = (data['name'] as String?) ?? widget.currentUserName;
        _birthdayController.text = (data['birthday'] as String?) ?? '';
        _noteController.text = (data['statusNote'] as String?) ?? '';
        _selectedEmoji = (data['avatarEmoji'] as String?) ?? '🦊';
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
          const SnackBar(content: Text('No se pudo abrir la galería'), backgroundColor: kDangerColor),
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
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'name': _aliasController.text.trim().isEmpty ? widget.currentUserName : _aliasController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'statusNote': _noteController.text.trim(),
        'avatarEmoji': _selectedEmoji,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ Perfil en Nido actualizado'),
            backgroundColor: kSecondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar perfil'), backgroundColor: kDangerColor),
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
                  'Perfil en el Nido 🌿',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
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
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kPrimaryColor)))
            else ...[
              // ---- FOTO DE PERFIL LOCAL ----
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
                              color: kPrimaryColor.withValues(alpha: 0.1),
                              border: Border.all(color: kBorderColor, width: 2),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _localPhotoPath != null
                                ? Image.file(
                                    File(_localPhotoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(_selectedEmoji, style: const TextStyle(fontSize: 42)),
                                    ),
                                  )
                                : Center(
                                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 42)),
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_localPhotoPath != null)
                      TextButton.icon(
                        onPressed: _removePhoto,
                        icon: const Icon(Icons.delete_outline, size: 14, color: kTextMuted),
                        label: const Text(
                          'Quitar foto',
                          style: TextStyle(fontSize: 12, color: kTextMuted),
                        ),
                      )
                    else
                      Text(
                        'Toca para elegir foto de galería',
                        style: TextStyle(fontSize: 11, color: kTextMuted.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ---- EMOJI AVATAR (se muestra si no hay foto) ----
              const Text('Avatar Emoji:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextMuted)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? kPrimaryColor.withValues(alpha: 0.15) : kBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSel ? kPrimaryColor : kBorderColor, width: isSel ? 1.8 : 1.0),
                        ),
                        child: Center(child: Text(em, style: const TextStyle(fontSize: 22))),
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
                  prefixIcon: Icon(Icons.person_outline, size: 20, color: kTextMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _birthdayController,
                decoration: const InputDecoration(
                  labelText: 'Cumpleaños / Aniversario (Opcional)',
                  hintText: 'Ej: 14 de Febrero',
                  prefixIcon: Icon(Icons.cake_outlined, size: 20, color: kTextMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Estado o Nota Corta (Opcional)',
                  hintText: 'Ej: ¡Juntos en cada meta! 💕',
                  prefixIcon: Icon(Icons.edit_note_outlined, size: 20, color: kTextMuted),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar Mi Perfil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  const _PartnerHeaderCard({
    required this.coupleId,
    required this.userId,
    required this.userName,
    required this.inviteCode,
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

  /// Recarga la foto local al volver al foco (ej. después de cambiarla en el modal)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocalPhoto();
  }

  @override
  Widget build(BuildContext context) {
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
              // Dual Avatars
              SizedBox(
                width: 62,
                height: 42,
                child: Stack(
                  children: [
                    // Mi avatar: foto local si existe, si no emoji
                    GestureDetector(
                      onTap: () async {
                        await showProfileModal(
                          context,
                          widget.userId,
                          widget.coupleId,
                          widget.userName,
                        );
                        _loadLocalPhoto(); // refresca foto al cerrar modal
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.12),
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
                                errorBuilder: (_, __, ___) =>
                                    Text(myEmoji, style: const TextStyle(fontSize: 20)),
                              )
                            : Text(myEmoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPaired ? kSecondaryColor.withValues(alpha: 0.15) : kBackgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: kSurfaceColor, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(isPaired ? partnerEmoji : '❓', style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Partner Status Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isPaired ? '${widget.userName} & $partnerName' : 'Tú & Tu Pareja',
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
                            color: isPaired ? Colors.green.shade500 : Colors.amber.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaired
                          ? (partnerNote != null && partnerNote.isNotEmpty ? partnerNote : 'Conectados en Nido 💚')
                          : 'Esperando que tu pareja se una…',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPaired ? kTextMuted : Colors.amber.shade800,
                        fontWeight: isPaired ? FontWeight.w400 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.favorite_rounded, color: kPrimaryColor, size: 22),
                tooltip: 'Enviar Guiño 💕',
                onPressed: () => _showSendPingModalGlobal(context, widget.coupleId, widget.userName),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline, color: kTextMuted, size: 22),
                tooltip: 'Mi Perfil 👤',
                onPressed: () async {
                  await showProfileModal(context, widget.userId, widget.coupleId, widget.userName);
                  _loadLocalPhoto(); // refresca foto al cerrar modal de perfil
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
// NAVEGACIÓN PRINCIPAL (TABS)
// ==========================================
class MainNavigation extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;

  const MainNavigation({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _lastHandledPingId;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
        userName: widget.userName,
      ),
      AnalyticsScreen(
        coupleId: widget.coupleId,
        userName: widget.userName,
      ),
      ShoppingListScreen(
        coupleId: widget.coupleId,
        userId: widget.userId,
      ),
      SavingsGoalsScreen(coupleId: widget.coupleId),
    ];

    _listenToLovePings();
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

      if (createdBy.isNotEmpty && createdBy != widget.userName && date != null) {
        if (DateTime.now().difference(date).inSeconds < 30) {
          HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$createdBy te envió: "$message"',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: kPrimaryColor,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      }
    });
  }

  void _showSendPingModal(BuildContext context) {
    final pings = [
      '❤️ Te quiero mucho',
      '☕ ¿Un cafecito juntos?',
      '🥰 ¡Gracias por ser mi equipo!',
      '🌹 Pensando en ti',
      '🍰 ¡Hoy te invito el postre!',
      '🍕 ¿Pedimos comida rica hoy?',
      '🥂 ¡Salud por nuestro nido!',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: kSurfaceColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: kPrimaryColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Enviar Guiño de Amor 💕',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
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
              'Envia un mensaje instantáneo a la pantalla de tu pareja:',
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pings.map((p) => ActionChip(
                avatar: const Icon(Icons.favorite_rounded, size: 14, color: kPrimaryColor),
                label: Text(p, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                backgroundColor: kBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: kBorderColor),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('couples')
                      .doc(widget.coupleId)
                      .collection('pings')
                      .add({
                    'message': p,
                    'createdBy': widget.userName,
                    'date': Timestamp.now(),
                  });
                  HapticFeedback.mediumImpact();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✨ Guiño enviado: $p'),
                        backgroundColor: kSecondaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
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
              icon: Icon(Icons.account_balance_wallet_outlined, color: kTextMuted),
              selectedIcon: Icon(Icons.account_balance_wallet, color: kPrimaryColor),
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
// PANTALLA 1: DASHBOARD DE MOVIMIENTOS
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final String userId;
  final String userName;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    required this.userId,
    required this.userName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterType = 'all'; // 'all', 'expense', 'income'
  bool _disponibleExpanded = true;
  bool _movimientosExpanded = true;

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseBottomSheet(
        coupleId: widget.coupleId,
        userName: widget.userName,
      ),
    );
  }

  Stream<List<Expense>> _streamExpenses() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  void _showEditBudgetDialog(BuildContext context, double currentBudget) {
    final controller =
        TextEditingController(text: currentBudget.toInt().toString());

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
                await FirebaseFirestore.instance
                    .collection('couples')
                    .doc(widget.coupleId)
                    .update({'budget_limit': val});
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
                errorBuilder: (ctx, err, stack) => const Icon(Icons.favorite, color: kPrimaryColor, size: 24),
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
            icon: const Icon(Icons.logout_outlined, size: 20, color: kTextMuted),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('couples')
            .doc(widget.coupleId)
            .snapshots(),
        builder: (context, coupleSnapshot) {
          if (coupleSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimaryColor));
          }

          final coupleData =
              coupleSnapshot.data?.data() as Map<String, dynamic>?;
          final double budgetLimit =
              ((coupleData?['budget_limit'] as num?) ?? 2000.0).toDouble();
          final String inviteCode =
              (coupleData?['invite_code'] as String?) ?? '';
          final members =
              List<String>.from(coupleData?['members'] as List? ?? []);

          return StreamBuilder<List<Expense>>(
            stream: _streamExpenses(),
            builder: (context, expensesSnapshot) {
              final allTransactions = expensesSnapshot.data ?? [];
              
              // Totales de Ingresos vs Gastos
              double totalIngresos = 0;
              double totalGastos = 0;
              final Map<String, double> ingresosPorUsuario = {};

              for (var t in allTransactions) {
                if (t.isIncome) {
                  totalIngresos += t.amount;
                  final user = t.createdBy.isNotEmpty ? t.createdBy : 'Anon';
                  ingresosPorUsuario[user] = (ingresosPorUsuario[user] ?? 0) + t.amount;
                } else {
                  totalGastos += t.amount;
                }
              }

              // Disponible real
              final disponibleReal = (totalIngresos > 0 ? totalIngresos : budgetLimit) - totalGastos;
              final porcentajeGastado = totalIngresos > 0
                  ? (totalGastos / totalIngresos).clamp(0.0, 1.0)
                  : (totalGastos / budgetLimit).clamp(0.0, 1.0);

              // Filtrar movimientos según pestaña activa
              final filtered = allTransactions.where((t) {
                if (_filterType == 'income') return t.isIncome;
                if (_filterType == 'expense') return !t.isIncome;
                return true;
              }).toList();

              final waitingForPartner = members.length < 2;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _PartnerHeaderCard(
                        coupleId: widget.coupleId,
                        userId: widget.userId,
                        userName: widget.userName,
                        inviteCode: inviteCode,
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

                  // Tarjeta Disponible Real (colapsable)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(18, 16, 18, _disponibleExpanded ? 18 : 14),
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBorderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                                setState(() => _disponibleExpanded = !_disponibleExpanded);
                                HapticFeedback.selectionClick();
                              },
                              child: Row(
                                children: [
                                  const Text(
                                    'Disponible Real',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: kTextMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!_disponibleExpanded)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _SmoothCurrencyText(
                                        value: disponibleReal,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: disponibleReal < 0 ? kDangerColor : kTextDark,
                                        ),
                                      ),
                                    ),
                                  if (_disponibleExpanded)
                                    GestureDetector(
                                      onTap: () => _showEditBudgetDialog(context, budgetLimit),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: kBackgroundColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Meta: ${formatCurrency(budgetLimit)}',
                                              style: const TextStyle(fontSize: 11, color: kTextMuted),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.edit_outlined, size: 12, color: kPrimaryColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Icon(
                                    _disponibleExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: kTextMuted,
                                    size: 22,
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
                                children: [
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _SmoothCurrencyText(
                                      value: disponibleReal,
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: disponibleReal < 0 ? kDangerColor : kTextDark,
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
                                    builder: (_, val, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        backgroundColor: kBorderColor,
                                        color: porcentajeGastado >= 0.9
                                            ? kDangerColor
                                            : porcentajeGastado > 0.75
                                                ? Colors.orange.shade400
                                                : kSecondaryColor,
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
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.green.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Ingresos (+)',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formatCurrency(totalIngresos),
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.green.shade800),
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
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.red.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Gastos (-)',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formatCurrency(totalGastos),
                                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red.shade800),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (porcentajeGastado >= 0.85) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '¡Atención! Han gastado el ${(porcentajeGastado * 100).toInt()}% de los fondos.',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              secondChild: const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Encabezado de Movimientos (colapsable + botón añadir arriba)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() => _movimientosExpanded = !_movimientosExpanded);
                              HapticFeedback.selectionClick();
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Movimientos${filtered.isNotEmpty ? ' (${filtered.length})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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
                                const Spacer(),
                                Material(
                                  color: kPrimaryColor,
                                  borderRadius: BorderRadius.circular(14),
                                  elevation: 0,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _openAddExpenseSheet,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 4),
                                          Text(
                                            'Añadir',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedCrossFade(
                            firstCurve: Curves.easeOutCubic,
                            secondCurve: Curves.easeOutCubic,
                            sizeCurve: Curves.easeOutCubic,
                            crossFadeState: _movimientosExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 220),
                            firstChild: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildFilterChip('Todos', 'all'),
                                  const SizedBox(width: 4),
                                  _buildFilterChip('➖ Gastos', 'expense'),
                                  const SizedBox(width: 4),
                                  _buildFilterChip('➕ Ingresos', 'income'),
                                ],
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Lista de movimientos
                  if (_movimientosExpanded)
                    filtered.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: _EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'Sin movimientos registrados',
                                subtitle: 'Usa "Añadir" para registrar un ingreso o un gasto.',
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final ex = filtered[index];
                                  return _AnimatedListItem(
                                    index: index,
                                    child: _ExpenseCard(
                                      expense: ex,
                                      coupleId: widget.coupleId,
                                      currentUserName: widget.userName,
                                    ),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                          )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = value);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : kBorderColor,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : kTextMuted,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 2: ANÁLISIS & GRÁFICAS DEL NIDO
// ==========================================
class AnalyticsScreen extends StatelessWidget {
  final String coupleId;
  final String userName;

  const AnalyticsScreen({
    super.key,
    required this.coupleId,
    required this.userName,
  });

  Stream<List<Expense>> _streamExpenses() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                errorBuilder: (_, __, ___) => const Icon(Icons.favorite, color: kPrimaryColor, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Nido · Análisis', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _streamExpenses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }

          final transactions = snapshot.data ?? [];
          final expensesOnly = transactions.where((t) => !t.isIncome).toList();
          final incomesOnly = transactions.where((t) => t.isIncome).toList();

          final totalIngresos = incomesOnly.fold<double>(0, (sum, t) => sum + t.amount);
          final totalGastos = expensesOnly.fold<double>(0, (sum, t) => sum + t.amount);
          final ahorroNeto = totalIngresos - totalGastos;

          // Agrupar gastos por categoría
          final Map<String, double> gastosPorCategoria = {};
          for (var e in expensesOnly) {
            gastosPorCategoria[e.category] = (gastosPorCategoria[e.category] ?? 0) + e.amount;
          }

          final sortedCategories = gastosPorCategoria.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Agrupar ingresos por miembro
          final Map<String, double> ingresosPorMiembro = {};
          for (var i in incomesOnly) {
            final user = i.createdBy.isNotEmpty ? i.createdBy : 'Miembro';
            ingresosPorMiembro[user] = (ingresosPorMiembro[user] ?? 0) + i.amount;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Tarjeta Resumen — animación 0
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricTile('Ingresos', formatCurrency(totalIngresos), Colors.green.shade700),
                          _buildMetricTile('Gastos', formatCurrency(totalGastos), kDangerColor),
                          _buildMetricTile('Superávit', formatCurrency(ahorroNeto), ahorroNeto >= 0 ? Colors.blue.shade700 : kDangerColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Gráfica de Gastos por Categoría — animación 1
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark),
                      ),
                      const SizedBox(height: 16),
                      if (sortedCategories.isEmpty)
                        const Text('Aún no hay gastos registrados este mes.', style: TextStyle(color: kTextMuted, fontSize: 13))
                      else
                        ...sortedCategories.map((entry) {
                          final porcentaje = totalGastos > 0 ? (entry.value / totalGastos) : 0.0;
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
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark),
                                    ),
                                    Text(
                                      '${formatCurrency(entry.value)} (${(porcentaje * 100).toStringAsFixed(1)}%)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TweenAnimationBuilder<double>(
                                  key: ValueKey(entry.key),
                                  tween: Tween(begin: 0.0, end: porcentaje),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, val, __) => ClipRRect(
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

              // Aportantes al Fondo del Nido — animación 2
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
                        'Aportantes al Fondo del Nido',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark),
                      ),
                      const SizedBox(height: 16),
                      if (ingresosPorMiembro.isEmpty)
                        const Text('Aún no se han registrado ingresos este mes.', style: TextStyle(color: kTextMuted, fontSize: 13))
                      else
                        ...ingresosPorMiembro.entries.map((e) {
                          final pct = totalIngresos > 0 ? (e.value / totalIngresos) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: kSecondaryColor.withValues(alpha: 0.2),
                                  child: Text(
                                    e.key.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kSecondaryColor),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextDark)),
                                      const SizedBox(height: 2),
                                      TweenAnimationBuilder<double>(
                                        key: ValueKey(e.key),
                                        tween: Tween(begin: 0.0, end: pct),
                                        duration: const Duration(milliseconds: 900),
                                        curve: Curves.easeOutCubic,
                                        builder: (_, val, __) => ClipRRect(
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
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark),
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
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

// Tarjeta de código de invitación (misma estética que PairingScreen)
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
        color: kSecondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.3)),
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
            icon: const Icon(Icons.copy_rounded, size: 16, color: kPrimaryColor),
            label: const Text(
              'Copiar código',
              style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Card de movimiento (gasto o ingreso) con diseño visual único por categoría
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String coupleId;
  final String currentUserName;

  const _ExpenseCard({
    required this.expense,
    required this.coupleId,
    required this.currentUserName,
  });

  Color _categoryColor(String cat, bool isIncome) {
    if (isIncome) return const Color(0xFF2E7D32);
    switch (cat) {
      case 'Citas & Salidas':
      case 'Comida':
        return const Color(0xFFC97A5E);
      case 'Supermercado':
        return const Color(0xFF388E3C);
      case 'Viajes & Escapadas':
        return const Color(0xFF00838F);
      case 'Servicios & Hogar':
      case 'Hogar':
        return const Color(0xFFD84315);
      case 'Detalles & Sorpresas':
        return const Color(0xFF7B1FA2);
      case 'Entretenimiento':
      case 'Suscripciones':
        return const Color(0xFFE65100);
      case 'Ahorro Pareja':
        return const Color(0xFF00695C);
      case 'Transporte':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF7A9E8F);
    }
  }

  String _categoryEmoji(String cat) {
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
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
                      label: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      backgroundColor: isSelected ? kPrimaryColor.withValues(alpha: 0.12) : kBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSelected ? kPrimaryColor : kBorderColor),
                      ),
                      onPressed: () => setModalState(() => selectedReaction = r),
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
                    hintText: 'Ej: Está bien, pero la próxima lo vemos juntos 💬',
                    prefixIcon: Icon(Icons.edit_note_outlined, size: 20, color: kTextMuted),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final note = noteController.text.trim();
                    if (selectedReaction == null && note.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Elige una reacción o escribe una nota'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final reactionText = [
                      if (selectedReaction != null) selectedReaction,
                      if (note.isNotEmpty) note,
                    ].join(' · ');

                    Navigator.pop(ctx);
                    final updatedReactions = Map<String, String>.from(expense.reactions);
                    updatedReactions[currentUserName] = reactionText;

                    await FirebaseFirestore.instance
                        .collection('couples')
                        .doc(coupleId)
                        .collection('expenses')
                        .doc(expense.id)
                        .update({'reactions': updatedReactions});

                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Enviar respuesta', style: TextStyle(fontWeight: FontWeight.bold)),
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
          child: const Icon(Icons.delete_outline, color: kDangerColor),
        ),
        background: const SizedBox.shrink(),
        confirmDismiss: (_) async {
          bool confirm = false;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: kSurfaceColor,
              title: Text(
                isIncome ? '¿Eliminar ingreso?' : '¿Eliminar gasto?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
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
        onDismissed: (_) {
          FirebaseFirestore.instance
              .collection('couples')
              .doc(coupleId)
              .collection('expenses')
              .doc(expense.id)
              .delete();
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
                color: accentColor.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Barra lateral de color según categoría
                Container(
                  width: 5,
                  color: accentColor,
                ),

                // Contenido principal de la tarjeta
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Emojicon contenedor
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _categoryEmoji(expense.category),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Título & Subtítulo
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          expense.description.isEmpty
                                              ? (isIncome ? 'Ingreso al nido' : 'Gasto general')
                                              : expense.description,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: kTextDark,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        '${expense.category} · ${formatDate(expense.date)}',
                                        style: const TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Monto & Badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? Colors.green.shade50
                                        : accentColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${isIncome ? '+' : '-'}${formatCurrency(expense.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isIncome ? Colors.green.shade800 : kTextDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Fila inferior de detalles (Creador, Origen, Reacción)
                        Row(
                          children: [
                            // Badge de autor
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expense.createdBy,
                                    style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Badge Origen/Destino
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kBackgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '📍 ${expense.sourceOrDestination}',
                                style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600),
                              ),
                            ),

                            const Spacer(),

                            // Botón reaccionar
                            IconButton(
                              icon: const Icon(Icons.favorite_border_rounded, size: 16, color: kAccentColor),
                              onPressed: () => _showReactionPicker(context),
                              tooltip: 'Reaccionar',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),

                        if (expense.reactions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: expense.reactions.entries.map((e) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kPrimaryColor),
                              ),
                            )).toList(),
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
// PANTALLA 2: LISTA DE COMPRAS
// ==========================================
class ShoppingListScreen extends StatefulWidget {
  final String coupleId;
  final String userId;

  const ShoppingListScreen({
    super.key,
    required this.coupleId,
    required this.userId,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _itemController = TextEditingController();
  bool _isAdding = false;

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
      _itemController.clear();
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _toggleItem(
      String id, bool currentValue, String name) async {
    if (!currentValue) {
      _preguntarConvertirAGasto(id, name);
    } else {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .collection('shopping_list')
          .doc(id)
          .update({'isBought': false});
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
              'Ingresa el monto para registrarlo automáticamente en gastos compartidos.',
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
              await FirebaseFirestore.instance
                  .collection('couples')
                  .doc(widget.coupleId)
                  .collection('shopping_list')
                  .doc(itemId)
                  .update({'isBought': true});
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
                });
                final itemRef = FirebaseFirestore.instance
                    .collection('couples')
                    .doc(widget.coupleId)
                    .collection('shopping_list')
                    .doc(itemId);
                batch.delete(itemRef);
                await batch.commit();
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
          // Input de agregar item
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

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('couples')
                  .doc(widget.coupleId)
                  .collection('shopping_list')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.error_outline,
                    title: 'No se pudo cargar la lista',
                    subtitle: snapshot.error.toString(),
                  );
                }

                final docs = [...(snapshot.data?.docs ?? [])];
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aBought = (aData['isBought'] as bool?) ?? false;
                  final bBought = (bData['isBought'] as bool?) ?? false;
                  if (aBought != bBought) return aBought ? 1 : -1;
                  final aDate =
                      (aData['date'] as Timestamp?)?.toDate() ?? DateTime(0);
                  final bDate =
                      (bData['date'] as Timestamp?)?.toDate() ?? DateTime(0);
                  return aDate.compareTo(bDate);
                });

                if (docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Lista vacía',
                    subtitle: 'Añade los artículos que necesitan comprar.',
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isBought = (data['isBought'] as bool?) ?? false;

                    final String itemName = (data['name'] as String?) ??
                        (data['title'] as String?) ??
                        (data['item'] as String?) ??
                        (data['description'] as String?) ??
                        'Artículo sin nombre';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: isBought
                            ? kBackgroundColor
                            : kSurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBought
                              ? kBorderColor.withValues(alpha: 0.5)
                              : kBorderColor,
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          itemName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: isBought
                                ? TextDecoration.lineThrough
                                : null,
                            color: isBought ? kTextMuted : kTextDark,
                          ),
                        ),
                        trailing: Checkbox(
                          value: isBought,
                          activeColor: kSecondaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (_) => _toggleItem(
                            doc.id,
                            isBought,
                            itemName,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA 3: METAS DE AHORRO
// ==========================================
class SavingsGoalsScreen extends StatelessWidget {
  final String coupleId;
  const SavingsGoalsScreen({super.key, required this.coupleId});

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
            onPressed: () {
              Navigator.pop(ctx);
              titleController.dispose();
              targetController.dispose();
            },
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = parseFormattedAmount(targetController.text);
              if (titleController.text.trim().isNotEmpty && target > 0) {
                await FirebaseFirestore.instance
                    .collection('couples')
                    .doc(coupleId)
                    .collection('savings')
                    .add({
                  'title': titleController.text.trim(),
                  'target': target,
                  'current': 0.0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
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
            onPressed: () {
              Navigator.pop(ctx);
              amountController.dispose();
            },
            child: const Text('Cancelar', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) {
                await FirebaseFirestore.instance
                    .collection('couples')
                    .doc(coupleId)
                    .collection('savings')
                    .doc(goalId)
                    .update({'current': FieldValue.increment(val)});
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('couples')
            .doc(coupleId)
            .collection('savings')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.savings_outlined,
              title: 'Sin metas aún',
              subtitle: 'Crea su primera meta de ahorro juntos.',
            );
          }

          // Ordenar: no completadas primero, luego completadas
          final sorted = [...docs];
          sorted.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTarget = ((aData['target'] as num?) ?? 0).toDouble();
            final aCurrent = ((aData['current'] as num?) ?? 0).toDouble();
            final bTarget = ((bData['target'] as num?) ?? 0).toDouble();
            final bCurrent = ((bData['current'] as num?) ?? 0).toDouble();
            final aDone = aTarget > 0 && aCurrent >= aTarget;
            final bDone = bTarget > 0 && bCurrent >= bTarget;
            if (aDone && !bDone) return 1;
            if (!aDone && bDone) return -1;
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final doc = sorted[index];
              final data = doc.data() as Map<String, dynamic>;
              final double target =
                  ((data['target'] as num?) ?? 0.0).toDouble();
              final double current =
                  ((data['current'] as num?) ?? 0.0).toDouble();
              // Protección contra división por cero
              final double progress =
                  target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
              final bool isCompleted = target > 0 && current >= target;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? kSecondaryColor.withValues(alpha: 0.06)
                      : kSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompleted
                        ? kSecondaryColor.withValues(alpha: 0.3)
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
                            (data['title'] as String?) ?? '',
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: kBorderColor,
                        color: isCompleted ? kSecondaryColor : kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formatCurrency(current)} de ${formatCurrency(target)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kTextMuted,
                          ),
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
                            doc.id,
                            current,
                            target,
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
                            side: const BorderSide(
                              color: kPrimaryColor,
                              width: 1.0,
                            ),
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
}

// ==========================================
// BOTTOM SHEET: AGREGAR MOVIMIENTO (GASTO O INGRESO)
// ==========================================
class AddExpenseBottomSheet extends StatefulWidget {
  final String coupleId;
  final String userName;

  const AddExpenseBottomSheet({
    super.key,
    required this.coupleId,
    required this.userName,
  });

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController(text: 'Cuenta Principal');
  
  String _transactionType = 'expense'; // 'expense' o 'income'
  String _selectedCategory = 'Citas & Salidas';
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _expenseCategories = [
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

  static const List<Map<String, dynamic>> _incomeCategories = [
    {'name': 'Sueldo / Nómina', 'icon': Icons.attach_money_outlined},
    {'name': 'Freelance / Trabajo', 'icon': Icons.work_outline},
    {'name': 'Rendimientos', 'icon': Icons.trending_up_outlined},
    {'name': 'Regalo / Bono', 'icon': Icons.card_giftcard_outlined},
    {'name': 'Ahorro Previo', 'icon': Icons.account_balance_outlined},
    {'name': 'Otros', 'icon': Icons.more_horiz_outlined},
  ];

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .collection('expenses')
          .add({
        'type': _transactionType,
        'amount': amount,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'sourceOrDestination': _sourceController.text.trim().isEmpty ? 'General' : _sourceController.text.trim(),
        'createdBy': widget.userName,
        'date': Timestamp.now(),
      });

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
    final categories = isIncome ? _incomeCategories : _expenseCategories;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de agarre
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

          // Selector de Tipo de Movimiento [ Gasto | Ingreso ]
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
                        _selectedCategory = 'Citas & Salidas';
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isIncome ? kPrimaryColor : Colors.transparent,
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
                        _selectedCategory = 'Sueldo / Nómina';
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isIncome ? Colors.green.shade600 : Colors.transparent,
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

          // Input de monto
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: isIncome ? Colors.green.shade700 : kTextDark,
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
                color: isIncome ? Colors.green.shade700 : kTextDark,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Input de descripción
          TextField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: isIncome ? '¿De qué es este ingreso?' : '¿En qué se gastó?',
              prefixIcon: const Icon(
                Icons.notes_outlined,
                size: 20,
                color: kTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Input de Origen / Destino
          TextField(
            controller: _sourceController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: isIncome ? 'Origen (ej: Cuenta Nómina, Efectivo)' : 'Método / Cuenta (ej: Tarjeta Compartida)',
              prefixIcon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: kTextMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selector de categorías
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
                    avatar: Icon(
                      cat['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : kTextMuted,
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat['name'] as String);
                      HapticFeedback.selectionClick();
                    },
                    selectedColor: isIncome ? Colors.green.shade600 : kPrimaryColor,
                    backgroundColor: kSurfaceColor,
                    side: BorderSide(
                      color: isSelected ? (isIncome ? Colors.green.shade600 : kPrimaryColor) : kBorderColor,
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

          // Botón guardar
          ElevatedButton(
            onPressed: _isSaving ? null : _guardarMovimiento,
            style: ElevatedButton.styleFrom(
              backgroundColor: isIncome ? Colors.green.shade700 : kPrimaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: (isIncome ? Colors.green.shade700 : kPrimaryColor).withValues(alpha: 0.5),
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
                    isIncome ? 'Guardar Ingreso' : 'Registrar Gasto',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
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
                color: kPrimaryColor.withValues(alpha: 0.08),
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


