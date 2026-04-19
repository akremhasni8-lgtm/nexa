import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/ai_service.dart';
import '../../services/zone_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String imagePath;
  final CameraArgs? cameraArgs; // ✅ contexte zones depuis la rotation
  const AnalysisScreen({super.key, required this.imagePath, this.cameraArgs});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {

  final _aiService = AIService();
  bool _isAnalyzing = false;
  String _statusText = '';

  String _espece = 'Vache';
  int _troupeauSize = 10;
  double _surfaceHa = 0;
  String _zoneName = '';

  late AnimationController _loaderController;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // ✅ Lire automatiquement depuis le profil éleveur
    final profileBox = Hive.box<EleveurProfile>('profile');
    if (profileBox.values.isNotEmpty) {
      final profile = profileBox.values.first;
      setState(() {
        _espece      = profile.espece;
        _troupeauSize = profile.troupeauSize;
      });
    }
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    // ✅ Validation — surface obligatoire
    if (_surfaceHa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Tracez votre zone sur la carte ou ajustez la surface'),
          backgroundColor: NexaTheme.or,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Prétraitement de l\'image...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _statusText = 'Analyse IA en cours...');

      final results = await _aiService.analyzeImage(widget.imagePath);

      setState(() => _statusText = 'Calcul de la biomasse...');
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() => _statusText = 'Génération du plan de rotation...');
      await Future.delayed(const Duration(milliseconds: 500));

      final analysisResult = AnalysisResult(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        imagePath: widget.imagePath,
        greenG:  results['green']  ?? 0,
        cloverG: results['clover'] ?? 0,
        deadG:   results['dead']   ?? 0,
        surfaceHa: _surfaceHa,
        troupeauSize: _troupeauSize,
        espece: _espece,
        // ✅ Nom de zone automatique si on vient d'une rotation
        zoneName: _zoneName.isNotEmpty
            ? _zoneName
            : widget.cameraArgs != null
                ? 'Zone ${widget.cameraArgs!.zoneAnalyseeId}'
                : null,
      );

      // Sauvegarder en local (offline)
      final box = Hive.box<AnalysisResult>('analyses');
      await box.add(analysisResult);

      if (mounted) {
        // ✅ Si on vient d'une rotation, mettre à jour les zones avec le résultat
        List<TerrainZone>? zonesMAJ;
        if (widget.cameraArgs != null) {
          zonesMAJ = ZoneService.mettreAJourApresAnalyse(
            widget.cameraArgs!.zones,
            widget.cameraArgs!.zoneAnalyseeId,
            analysisResult,
          );
          await ZoneService.sauvegarderZones(zonesMAJ);
        }

        context.pushReplacement('/results', extra: {
          'result': analysisResult,
          'zoneId': widget.cameraArgs?.zoneAnalyseeId,
          'zones': zonesMAJ, // zones complètes mises à jour
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: NexaTheme.rouge,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(
        children: [
          // Contenu principal
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: NexaTheme.noir,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => context.pop(),
                ),
                title: Text('CONFIGURER', style: NexaTheme.displayM.copyWith(fontSize: 22)),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Preview image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

                    const SizedBox(height: 24),

                    // ✅ Résumé du profil (lecture seule)
                    _ProfilResume(espece: _espece, troupeauSize: _troupeauSize)
                        .animate().fadeIn(duration: 400.ms, delay: 100.ms),

                    const SizedBox(height: 24),

                    // Surface
                    Row(
                      children: [
                        Expanded(
                          child: NexaEyebrow(
                            _surfaceHa > 0
                                ? 'Surface : ${_surfaceHa.toStringAsFixed(2)} ha ${_surfaceHa != _surfaceHa.roundToDouble() ? "📍 tracée" : ""}'
                                : 'Surface : non définie',
                          ),
                        ),
                        if (_surfaceHa > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NexaTheme.vert.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NexaTheme.vert.withOpacity(0.3)),
                            ),
                            child: Text(
                              '📍 ${_surfaceHa.toStringAsFixed(2)} ha',
                              style: NexaTheme.label.copyWith(color: NexaTheme.vert, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    NexaCard(
                      child: Column(
                        children: [
                          Slider(
                            value: _surfaceHa.clamp(1, 500),
                            min: 1, max: 500,
                            divisions: 499,
                            activeColor: NexaTheme.vert,
                            inactiveColor: NexaTheme.blanc.withOpacity(0.1),
                            onChanged: (v) => setState(() => _surfaceHa = v),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('1 ha', style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
                              GestureDetector(
                                onTap: () async {
                                  // ✅ Récupérer la surface retournée par la carte
                                  final surface = await context.push<double>('/map');
                                  if (surface != null && surface > 0) {
                                    setState(() => _surfaceHa = surface);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✅ Zone de ${surface.toStringAsFixed(2)} ha importée'),
                                        backgroundColor: NexaTheme.vert,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: NexaTheme.vert.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: NexaTheme.vert.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.map_outlined, color: NexaTheme.vert, size: 14),
                                      const SizedBox(width: 4),
                                      Text('Tracer sur carte', style: NexaTheme.bodyS.copyWith(color: NexaTheme.vert)),
                                    ],
                                  ),
                                ),
                              ),
                              Text('500 ha', style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

                    const SizedBox(height: 32),

                    // Bouton analyser
                    NexaButton(
                      label: 'LANCER L\'ANALYSE IA →',
                      isLoading: _isAnalyzing,
                      onTap: _runAnalysis,
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
                  ]),
                ),
              ),
            ],
          ),

          // Overlay d'analyse
          if (_isAnalyzing)
            _AnalysisOverlay(
              statusText: _statusText,
              controller: _loaderController,
            ),
        ],
      ),
    );
  }

  String _especeEmoji(String espece) {
    switch (espece) {
      case 'Vache':   return '🐄';
      case 'Mouton':  return '🐑';
      case 'Chèvre':  return '🐐';
      case 'Chameau': return '🐪';
      default: return '🐾';
    }
  }
}

// ── RÉSUMÉ PROFIL ─────────────────────────────────────────

class _ProfilResume extends StatelessWidget {
  final String espece;
  final int troupeauSize;
  const _ProfilResume({required this.espece, required this.troupeauSize});

  String get _emoji {
    switch (espece) {
      case 'Vache':   return '🐄';
      case 'Mouton':  return '🐑';
      case 'Chèvre':  return '🐐';
      case 'Chameau': return '🐪';
      default: return '🐾';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NexaTheme.vert.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexaTheme.vert.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Troupeau · $espece',
                  style: NexaTheme.titleL.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '$troupeauSize têtes · données issues de votre profil',
                  style: NexaTheme.bodyS.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/questionnaire'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NexaTheme.blanc.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NexaTheme.blanc.withOpacity(0.1)),
              ),
              child: Text(
                'Modifier',
                style: NexaTheme.label.copyWith(
                  color: NexaTheme.blanc.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisOverlay extends StatelessWidget {
  final String statusText;
  final AnimationController controller;

  const _AnalysisOverlay({required this.statusText, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexaTheme.noir.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: controller.value * 6.28,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [NexaTheme.vert, NexaTheme.vert.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: NexaTheme.noir,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.grain, color: NexaTheme.vert, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('ANALYSE EN COURS', style: NexaTheme.displayM.copyWith(fontSize: 22, color: NexaTheme.vert)),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}