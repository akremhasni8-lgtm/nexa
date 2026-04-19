import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;        // true = login, false = register
  bool _obscurePass = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  String? _errorMsg;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // ── ACTIONS ───────────────────────────────────────────────

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      if (_isLogin) {
        await _auth.signInWithEmail(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
      } else {
        await _auth.registerWithEmail(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
      }
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _errorMsg = null; });
    try {
      final result = await _auth.signInWithGoogle();
      if (result != null && mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (_) {
      setState(() => _errorMsg = 'Connexion Google annulée.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _continueAsVisitor() async {
    HapticFeedback.lightImpact();
    await _auth.continueAsVisitor();
    if (mounted) context.go('/');
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Entrez votre email pour réinitialiser.');
      return;
    }
    try {
      await _auth.resetPassword(_emailCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email envoyé à ${_emailCtrl.text}'),
            backgroundColor: NexaTheme.vert,
          ),
        );
      }
    } catch (_) {
      setState(() => _errorMsg = 'Impossible d\'envoyer l\'email.');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [

          // ── FOND ANIMÉ ─────────────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _AuthBgPainter(_bgController.value),
            ),
          ),

          // ── CONTENU ────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [

                      // ── HEADER ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Column(
                          children: [
                            // Logo
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: NexaTheme.noir2,
                                border: Border.all(
                                  color: NexaTheme.vert.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: NexaTheme.vert.withOpacity(0.2),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo-nexa.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      'N',
                                      style: NexaTheme.displayM.copyWith(
                                        color: NexaTheme.vert,
                                        fontSize: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ).animate().scale(
                              begin: const Offset(0.7, 0.7),
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'NEXA',
                              style: NexaTheme.displayXL.copyWith(
                                fontSize: 42,
                                letterSpacing: 8,
                              ),
                            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                            const SizedBox(height: 6),

                            Text(
                              _isLogin ? 'Bon retour 👋' : 'Créer un compte',
                              style: NexaTheme.bodyM.copyWith(
                                color: NexaTheme.blanc.withOpacity(0.45),
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── FORMULAIRE ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [

                              // Email
                              _NexaField(
                                controller: _emailCtrl,
                                label: 'Email',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email requis';
                                  if (!v.contains('@')) return 'Email invalide';
                                  return null;
                                },
                              ).animate().fadeIn(duration: 400.ms, delay: 350.ms)
                               .slideY(begin: 0.2, duration: 400.ms, delay: 350.ms),

                              const SizedBox(height: 12),

                              // Mot de passe
                              _NexaField(
                                controller: _passCtrl,
                                label: 'Mot de passe',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePass,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: NexaTheme.blanc.withOpacity(0.4),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Mot de passe requis';
                                  if (!_isLogin && v.length < 6) return '6 caractères minimum';
                                  return null;
                                },
                              ).animate().fadeIn(duration: 400.ms, delay: 420.ms)
                               .slideY(begin: 0.2, duration: 400.ms, delay: 420.ms),

                              // Mot de passe oublié
                              if (_isLogin)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _resetPassword,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    child: Text(
                                      'Mot de passe oublié ?',
                                      style: NexaTheme.bodyS.copyWith(
                                        color: NexaTheme.vert.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Message d'erreur
                              if (_errorMsg != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red.shade400, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMsg!,
                                          style: NexaTheme.bodyS.copyWith(
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().shakeX(duration: 400.ms),

                              const SizedBox(height: 20),

                              // Bouton principal
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: NexaTheme.vert,
                                    foregroundColor: NexaTheme.noir,
                                    disabledBackgroundColor:
                                        NexaTheme.vert.withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: NexaTheme.vert.withOpacity(0.4),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: NexaTheme.noir,
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? 'Se connecter' : 'Créer mon compte',
                                          style: NexaTheme.titleL.copyWith(
                                            color: NexaTheme.noir,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ).animate().fadeIn(duration: 400.ms, delay: 480.ms),

                              const SizedBox(height: 16),

                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: NexaTheme.blanc.withOpacity(0.1),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'ou',
                                      style: NexaTheme.bodyS.copyWith(
                                        color: NexaTheme.blanc.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: NexaTheme.blanc.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Google Sign In
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: _googleLoading ? null : _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: NexaTheme.blanc.withOpacity(0.2),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: NexaTheme.blanc.withOpacity(0.04),
                                  ),
                                  child: _googleLoading
                                      ? SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: NexaTheme.blanc.withOpacity(0.6),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Logo Google SVG simplifié
                                            _GoogleLogo(),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Continuer avec Google',
                                              style: NexaTheme.bodyM.copyWith(
                                                color: NexaTheme.blanc.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ).animate().fadeIn(duration: 400.ms, delay: 520.ms),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── BAS DE PAGE ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                        child: Column(
                          children: [

                            // Toggle login/register
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? 'Pas encore de compte ? '
                                      : 'Déjà un compte ? ',
                                  style: NexaTheme.bodyS.copyWith(
                                    color: NexaTheme.blanc.withOpacity(0.4),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _isLogin = !_isLogin;
                                    _errorMsg = null;
                                  }),
                                  child: Text(
                                    _isLogin ? 'S\'inscrire' : 'Se connecter',
                                    style: NexaTheme.bodyS.copyWith(
                                      color: NexaTheme.vert,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Séparateur
                            Divider(color: NexaTheme.blanc.withOpacity(0.08)),

                            const SizedBox(height: 12),

                            // Continue comme visiteur
                            GestureDetector(
                              onTap: _continueAsVisitor,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: NexaTheme.blanc.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.explore_outlined,
                                      color: NexaTheme.blanc.withOpacity(0.4),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Continuer comme visiteur',
                                      style: NexaTheme.bodyM.copyWith(
                                        color: NexaTheme.blanc.withOpacity(0.4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NexaTheme.or.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '1 scan',
                                        style: NexaTheme.label.copyWith(
                                          color: NexaTheme.or,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

                            const SizedBox(height: 8),

                            Text(
                              'Accès limité à 1 analyse gratuite',
                              style: NexaTheme.bodyS.copyWith(
                                color: NexaTheme.blanc.withOpacity(0.2),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CHAMP DE TEXTE ────────────────────────────────────────

class _NexaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _NexaField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc),
      cursorColor: NexaTheme.vert,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: NexaTheme.bodyS.copyWith(
          color: NexaTheme.blanc.withOpacity(0.4),
        ),
        prefixIcon: Icon(icon, color: NexaTheme.vert.withOpacity(0.6), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: NexaTheme.blanc.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: NexaTheme.blanc.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: NexaTheme.blanc.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NexaTheme.vert, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        errorStyle: NexaTheme.bodyS.copyWith(color: Colors.red.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ── LOGO GOOGLE ───────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Cercle de fond blanc
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..color = Colors.white,
    );

    // Lettre G simplifiée avec 4 segments colorés
    final colors = [
      const Color(0xFF4285F4), // bleu
      const Color(0xFF34A853), // vert
      const Color(0xFFFBBC05), // jaune
      const Color(0xFFEA4335), // rouge
    ];

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.7);
    final sweepAngle = (2 * pi) / 4;

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        i * sweepAngle - pi / 4,
        sweepAngle * 0.85,
        false,
        Paint()
          ..color = colors[i]
          ..strokeWidth = r * 0.28
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── BACKGROUND PAINTER ────────────────────────────────────

class _AuthBgPainter extends CustomPainter {
  final double progress;
  const _AuthBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Lignes de champ
    final paint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    for (int i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      paint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x0A22C55E), Colors.transparent],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawLine(Offset(cx, size.height * 0.2), Offset(x, size.height), paint);
    }

    // Point lumineux animé
    final px = cx + cos(progress * 2 * pi) * 60;
    final py = size.height * 0.3 + sin(progress * 2 * pi) * 30;
    canvas.drawCircle(
      Offset(px, py),
      40,
      Paint()
        ..color = NexaTheme.vert.withOpacity(0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(_AuthBgPainter old) => old.progress != progress;
}