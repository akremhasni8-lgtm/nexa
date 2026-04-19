import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _ringController;
  late AnimationController _progressController;
  late AnimationController _glowController;

  String _loadingText = 'Initialisation...';
  bool _showLoader = false;
  bool _showName = false;
  bool _showLogo = false;
  bool _showTagline = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ringController     = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _glowController     = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() { _showLogo = true; _showName = true; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _showTagline = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showLoader = true);
    _progressController.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loadingText = 'Chargement du modèle IA...');
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _loadingText = 'Calibration capteurs...');
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loadingText = 'Prêt ✓');
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 500));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!mounted) return;

    final box = Hive.box('settings');
    final everOpened = box.get('ever_opened', defaultValue: false) as bool;

    if (!everOpened) {
      // Toute première fois → slides d'abord
      await box.put('ever_opened', true);
      if (mounted) context.go('/onboarding');
      return;
    }

    // Sinon → vérifier Firebase
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        await firebaseUser.reload();
      } catch (_) {
        await FirebaseAuth.instance.signOut();
      }
    }

    final isAuth = FirebaseAuth.instance.currentUser != null;
    if (mounted) context.go(isAuth ? '/' : '/login');
  }

  @override
  void dispose() {
    _ringController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(
        children: [
          // Fond
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [NexaTheme.vertDeep, NexaTheme.noir],
              ),
            ),
          ),

          // Rings
          Center(
            child: AnimatedBuilder(
              animation: _ringController,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(angle: _ringController.value * 2 * pi * 0.3,  child: _OrbitalRing(radius: 160, opacity: 0.08, dashes: 24)),
                  Transform.rotate(angle: -_ringController.value * 2 * pi * 0.6, child: _OrbitalRing(radius: 130, opacity: 0.12, dashes: 16)),
                  Transform.rotate(angle: _ringController.value * 2 * pi,         child: _OrbitalRing(radius: 100, opacity: 0.2,  dashes: 8)),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                AnimatedOpacity(
                  opacity: _showLogo ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 700),
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (_, child) => Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: NexaTheme.vert.withOpacity(0.2 + _glowController.value * 0.25),
                          blurRadius: 40 + _glowController.value * 20,
                          spreadRadius: 5 + _glowController.value * 8,
                        )],
                      ),
                      child: child,
                    ),
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NexaTheme.noir2,
                        border: Border.all(color: NexaTheme.vert.withOpacity(0.4), width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo-nexa.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text('N', style: NexaTheme.displayXL.copyWith(color: NexaTheme.vert, fontSize: 56)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // NEXA
                AnimatedOpacity(
                  opacity: _showName ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 700),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [NexaTheme.blanc, NexaTheme.vert, NexaTheme.blanc],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text('NEXA', style: NexaTheme.displayXL.copyWith(
                      fontSize: 72, letterSpacing: 12, color: NexaTheme.blanc,
                    )),
                  ),
                ),

                const SizedBox(height: 12),

                AnimatedOpacity(
                  opacity: _showTagline ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    'Intelligence Pastorale · Afrique',
                    style: NexaTheme.label.copyWith(
                      color: NexaTheme.blanc.withOpacity(0.4),
                      letterSpacing: 3, fontSize: 11,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Loader
                AnimatedOpacity(
                  opacity: _showLoader ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _loadingText,
                            key: ValueKey(_loadingText),
                            style: NexaTheme.label.copyWith(
                              color: NexaTheme.blanc.withOpacity(0.35),
                              letterSpacing: 1.5, fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (_, __) {
                            final w = MediaQuery.of(context).size.width - 80;
                            return SizedBox(
                              height: 8,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(height: 2, decoration: BoxDecoration(color: NexaTheme.blanc.withOpacity(0.06), borderRadius: BorderRadius.circular(1))),
                                  FractionallySizedBox(
                                    widthFactor: _progressController.value,
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [NexaTheme.vertDeep, NexaTheme.vert]),
                                        borderRadius: BorderRadius.circular(1),
                                        boxShadow: [BoxShadow(color: NexaTheme.vert.withOpacity(0.6), blurRadius: 6)],
                                      ),
                                    ),
                                  ),
                                  if (_progressController.value > 0.02)
                                    Positioned(
                                      left: w * _progressController.value - 4,
                                      child: Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(color: NexaTheme.vert, shape: BoxShape.circle, boxShadow: [BoxShadow(color: NexaTheme.vert, blurRadius: 8)]),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitalRing extends StatelessWidget {
  final double radius, opacity;
  final int dashes;
  const _OrbitalRing({required this.radius, required this.opacity, required this.dashes});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(radius * 2, radius * 2),
    painter: _DashedCirclePainter(radius: radius, opacity: opacity, dashes: dashes),
  );
}

class _DashedCirclePainter extends CustomPainter {
  final double radius, opacity;
  final int dashes;
  const _DashedCirclePainter({required this.radius, required this.opacity, required this.dashes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NexaTheme.vert.withOpacity(opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final dashAngle = (2 * pi) / dashes;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle, dashAngle * 0.6, false, paint,
      );
    }
  }
  @override
  bool shouldRepaint(_) => false;
}