import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

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
          return const LoadingScaffold();
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
          return const LoadingScaffold();
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

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key});

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
        _showSnackbar(mapFirebaseError(e), isError: true);
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
          ? const LoadingScaffold()
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
