import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/zone_service.dart';

class CameraScreen extends StatefulWidget {
  final CameraArgs? cameraArgs; // ✅ contexte zones optionnel
  const CameraScreen({super.key, this.cameraArgs});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _isTakingPhoto = false;

  late AnimationController _scanController;
  late AnimationController _shutterController;
  late AnimationController _cornerController;
  late AnimationController _tipController;

  int _currentTip = 0;
  final List<_Tip> _tips = const [
    _Tip('🌿', 'Cadrez uniquement l\'herbe', 'Évitez ciel, arbres et obstacles'),
    _Tip('☀️', 'Pleine lumière naturelle', 'Évitez les ombres sur le sol'),
    _Tip('📐', 'À 80–100 cm du sol', 'Gardez l\'appareil horizontal'),
    _Tip('🌾', 'Zone représentative', 'Choisissez une zone typique du pâturage'),
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _tipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _tipController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _currentTip = (_currentTip + 1) % _tips.length);
      }
    });

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _cameraReady = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanController.dispose();
    _shutterController.dispose();
    _cornerController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);
    HapticFeedback.mediumImpact();
    await _shutterController.forward();

    try {
      XFile? photo;
      if (_cameraReady && _cameraController != null) {
        photo = await _cameraController!.takePicture();
      } else {
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      }
      if (photo != null && mounted) context.push('/analysis', extra: {'imagePath': photo.path, 'cameraArgs': widget.cameraArgs});
    } catch (_) {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (photo != null && mounted) context.push('/analysis', extra: {'imagePath': photo.path, 'cameraArgs': widget.cameraArgs});
    } finally {
      if (mounted) {
        _shutterController.reverse();
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (photo != null && mounted) context.push('/analysis', extra: {'imagePath': photo.path, 'cameraArgs': widget.cameraArgs});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── PREVIEW / FOND ─────────────────────────────────
          if (_cameraReady && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.3,
                  colors: [Color(0xFF0D2B1A), Color(0xFF040804)],
                ),
              ),
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (_, __) => CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(_scanController.value),
                ),
              ),
            ),

          // ── VIGNETTE ───────────────────────────────────────
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── CADRE DE SCAN ──────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_scanController, _cornerController]),
              builder: (_, __) {
                final frameSize = size.width * 0.75;
                return SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: CustomPaint(
                    painter: _FramePainter(
                      scanProgress: _scanController.value,
                      pulseProgress: _cornerController.value,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── FLASH SHUTTER ──────────────────────────────────
          AnimatedBuilder(
            animation: _shutterController,
            builder: (_, __) => Opacity(
              opacity: (1 - _shutterController.value) * _shutterController.value * 4,
              child: Container(color: Colors.white),
            ),
          ),

          // ── UI LAYOUT ──────────────────────────────────────
          SafeArea(
            child: Column(
              children: [

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ANALYSER', style: NexaTheme.displayM.copyWith(fontSize: 22, color: Colors.white)),
                          Text(
                            'Cadrez votre pâturage',
                            style: NexaTheme.bodyS.copyWith(color: Colors.white.withOpacity(0.45)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const Spacer(),

                // Tip rotatif
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _TipBanner(key: ValueKey(_currentTip), tip: _tips[_currentTip]),
                ),

                const SizedBox(height: 32),

                // Contrôles bas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // Galerie
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Icon(Icons.photo_library_outlined, color: Colors.white.withOpacity(0.7), size: 22),
                        ),
                      ),

                      // Bouton shutter
                      GestureDetector(
                        onTap: _isTakingPhoto ? null : _capturePhoto,
                        child: AnimatedBuilder(
                          animation: _shutterController,
                          builder: (_, __) => Transform.scale(
                            scale: 1.0 - _shutterController.value * 0.08,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: NexaTheme.vert.withOpacity(0.5), width: 2),
                                  ),
                                ),
                                Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isTakingPhoto ? NexaTheme.vert.withOpacity(0.8) : NexaTheme.vert,
                                    boxShadow: [
                                      BoxShadow(color: NexaTheme.vert.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                                    ],
                                  ),
                                  child: _isTakingPhoto
                                      ? const Padding(
                                          padding: EdgeInsets.all(18),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: NexaTheme.noir),
                                        )
                                      : const Icon(Icons.grass_rounded, color: NexaTheme.noir, size: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Flip (décoratif pour l'instant)
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Icon(Icons.flip_camera_ios_outlined, color: Colors.white.withOpacity(0.7), size: 22),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.3, duration: 500.ms).fadeIn(duration: 500.ms),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── TIP ───────────────────────────────────────────────────

class _Tip {
  final String emoji;
  final String title;
  final String subtitle;
  const _Tip(this.emoji, this.title, this.subtitle);
}

class _TipBanner extends StatelessWidget {
  final _Tip tip;
  const _TipBanner({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexaTheme.vert.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tip.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tip.title, style: NexaTheme.titleM.copyWith(color: Colors.white, fontSize: 13)),
              Text(tip.subtitle, style: NexaTheme.bodyS.copyWith(color: Colors.white.withOpacity(0.45), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── FRAME PAINTER ─────────────────────────────────────────

class _FramePainter extends CustomPainter {
  final double scanProgress;
  final double pulseProgress;
  const _FramePainter({required this.scanProgress, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cl = w * 0.12;
    final co = 0.6 + pulseProgress * 0.4;

    final cp = Paint()
      ..color = NexaTheme.vert.withOpacity(co)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Coins
    canvas.drawLine(Offset.zero, Offset(cl, 0), cp);
    canvas.drawLine(Offset.zero, Offset(0, cl), cp);
    canvas.drawLine(Offset(w, 0), Offset(w - cl, 0), cp);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), cp);
    canvas.drawLine(Offset(0, h), Offset(cl, h), cp);
    canvas.drawLine(Offset(0, h), Offset(0, h - cl), cp);
    canvas.drawLine(Offset(w, h), Offset(w - cl, h), cp);
    canvas.drawLine(Offset(w, h), Offset(w, h - cl), cp);

    // Points coins
    final dp = Paint()..color = NexaTheme.vert.withOpacity(co)..style = PaintingStyle.fill;
    for (final o in [Offset.zero, Offset(w, 0), Offset(0, h), Offset(w, h)]) {
      canvas.drawCircle(o, 3, dp);
    }

    // Ligne de scan
    final sy = h * scanProgress;
    canvas.drawRect(
      Rect.fromLTWH(0, sy, w, 1.5),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, NexaTheme.vert.withOpacity(0.9), NexaTheme.vert, NexaTheme.vert.withOpacity(0.9), Colors.transparent],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(Rect.fromLTWH(0, sy, w, 1.5)),
    );

    // Glow scan
    canvas.drawRect(
      Rect.fromLTWH(0, sy, w, 20),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NexaTheme.vert.withOpacity(0.15), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, sy, w, 20)),
    );

    // Croix centrale
    final xp = Paint()..color = NexaTheme.vert.withOpacity(0.3)..strokeWidth = 1;
    canvas.drawLine(Offset(w / 2 - 10, h / 2), Offset(w / 2 + 10, h / 2), xp);
    canvas.drawLine(Offset(w / 2, h / 2 - 10), Offset(w / 2, h / 2 + 10), xp);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, Paint()..color = NexaTheme.vert.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.scanProgress != scanProgress || old.pulseProgress != pulseProgress;
}

// ── GRID PAINTER ──────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double progress;
  const _GridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = NexaTheme.vert.withOpacity(0.04)..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    final sy = size.height * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, sy, size.width, 2),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, NexaTheme.vert.withOpacity(0.25), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, sy, size.width, 2)),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.progress != progress;
}