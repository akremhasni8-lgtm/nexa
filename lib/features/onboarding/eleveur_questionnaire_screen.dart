import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class EleveurQuestionnaireScreen extends StatefulWidget {
  const EleveurQuestionnaireScreen({super.key});

  @override
  State<EleveurQuestionnaireScreen> createState() =>
      _EleveurQuestionnaireScreenState();
}

class _EleveurQuestionnaireScreenState
    extends State<EleveurQuestionnaireScreen> {

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Réponses (sans nom — on prend l'email Firebase)
  String _espece = 'bovins';
  int _troupeau = 50;
  bool _isNomade = false;
  double _distanceMax = 50;

  final List<String> _especes = ['bovins', 'ovins', 'caprins', 'camelins'];
  static const int _totalPages = 3;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _saveAndContinue();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final user = FirebaseAuth.instance.currentUser;
    final uid  = user?.uid ?? 'unknown';

    // Nom = displayName Firebase ou partie avant @ de l'email
    final email = user?.email ?? '';
    final nom = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : email.contains('@') ? email.split('@')[0] : 'Éleveur';
    final profile = EleveurProfile(
      nom: nom,
      espece: _espece,
      troupeauSize: _troupeau,
      region: '',
      isNomade: _isNomade,
      createdAt: DateTime.now(),
    );

    // Sauvegarder le profil lié au UID
    final profileBox = Hive.box<EleveurProfile>('profile');
    await profileBox.clear();
    await profileBox.add(profile);

    // Marquer questionnaire fait pour CE compte
    await Hive.box('settings').put('questionnaire_done_$uid', true);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.2,
                colors: [NexaTheme.vertDeep, NexaTheme.noir],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [

                // ── HEADER ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo-nexa.png',
                                height: 36,
                                width: 36,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'NEXA',
                                style: NexaTheme.displayM.copyWith(
                                  color: NexaTheme.vert,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_currentPage + 1} / $_totalPages',
                            style: NexaTheme.label.copyWith(
                              color: NexaTheme.blanc.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / _totalPages,
                          backgroundColor: NexaTheme.blanc.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(NexaTheme.vert),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── PAGES ──────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _PageEspece(
                        selected: _espece,
                        especes: _especes,
                        onSelect: (e) => setState(() => _espece = e),
                      ),
                      _PageTroupeau(
                        value: _troupeau,
                        onChanged: (v) => setState(() => _troupeau = v),
                      ),
                      _PageMobilite(
                        isNomade: _isNomade,
                        distanceMax: _distanceMax,
                        onMobiliteChanged: (v) => setState(() => _isNomade = v),
                        onDistanceChanged: (v) => setState(() => _distanceMax = v),
                      ),
                    ],
                  ),
                ),

                // ── NAVIGATION ─────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24, 0, 24,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: Row(
                    children: [
                      if (_currentPage > 0) ...[
                        GestureDetector(
                          onTap: _prevPage,
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: NexaTheme.blanc.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: NexaTheme.blanc.withOpacity(0.1)),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                              color: NexaTheme.blanc.withOpacity(0.6)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _nextPage,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: NexaTheme.vert,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: NexaTheme.vert.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: NexaTheme.noir,
                                      ),
                                    )
                                  : Text(
                                      _currentPage == _totalPages - 1
                                          ? 'Commencer →'
                                          : 'Suivant →',
                                      style: NexaTheme.titleM.copyWith(
                                        color: NexaTheme.noir,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PAGE 1 — ESPÈCE ───────────────────────────────────────

class _PageEspece extends StatelessWidget {
  final String selected;
  final List<String> especes;
  final ValueChanged<String> onSelect;

  const _PageEspece({
    required this.selected,
    required this.especes,
    required this.onSelect,
  });

  String _emoji(String e) {
    switch (e) {
      case 'bovins':   return '🐄';
      case 'ovins':    return '🐑';
      case 'caprins':  return '🐐';
      case 'camelins': return '🐪';
      default:         return '🐄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Votre type\nde bétail ?',
            style: NexaTheme.displayM.copyWith(fontSize: 32),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text('Sélectionnez l\'espèce principale.',
            style: NexaTheme.bodyM.copyWith(
              color: NexaTheme.blanc.withOpacity(0.4),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 32),
          ...especes.asMap().entries.map((entry) {
            final e = entry.value;
            final isSelected = e == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NexaTheme.vert.withOpacity(0.15)
                        : NexaTheme.blanc.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? NexaTheme.vert.withOpacity(0.6)
                          : NexaTheme.blanc.withOpacity(0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_emoji(e), style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 16),
                      Text(
                        e[0].toUpperCase() + e.substring(1),
                        style: NexaTheme.titleM.copyWith(
                          color: isSelected ? NexaTheme.vert : NexaTheme.blanc,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: NexaTheme.vert, size: 20),
                    ],
                  ),
                ),
              ).animate(delay: (entry.key * 80).ms).fadeIn().slideX(begin: 0.1),
            );
          }),
        ],
      ),
    );
  }
}

// ── PAGE 2 — TROUPEAU ─────────────────────────────────────

class _PageTroupeau extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PageTroupeau({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Taille de\nvotre troupeau ?',
            style: NexaTheme.displayM.copyWith(fontSize: 32),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text('Nombre de têtes approximatif.',
            style: NexaTheme.bodyM.copyWith(
              color: NexaTheme.blanc.withOpacity(0.4),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 50),

          Center(
            child: Text('$value',
              style: NexaTheme.displayXL.copyWith(fontSize: 80, color: NexaTheme.vert),
            ),
          ),
          Center(
            child: Text('têtes',
              style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
            ),
          ),
          const SizedBox(height: 32),

          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: NexaTheme.vert,
              inactiveTrackColor: NexaTheme.blanc.withOpacity(0.1),
              thumbColor: NexaTheme.vert,
              overlayColor: NexaTheme.vert.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1, max: 500, divisions: 99,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1', style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
                Text('500+', style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Wrap(
            spacing: 8, runSpacing: 8,
            children: [10, 25, 50, 100, 200, 300].map((v) =>
              GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: value == v
                        ? NexaTheme.vert.withOpacity(0.2)
                        : NexaTheme.blanc.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value == v
                          ? NexaTheme.vert.withOpacity(0.5)
                          : NexaTheme.blanc.withOpacity(0.08),
                    ),
                  ),
                  child: Text('$v',
                    style: NexaTheme.titleM.copyWith(
                      color: value == v ? NexaTheme.vert : NexaTheme.blanc,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ).toList(),
          ),
        ],
      ),
    );
  }
}

// ── PAGE 3 — MOBILITÉ ─────────────────────────────────────

class _PageMobilite extends StatelessWidget {
  final bool isNomade;
  final double distanceMax;
  final ValueChanged<bool> onMobiliteChanged;
  final ValueChanged<double> onDistanceChanged;

  const _PageMobilite({
    required this.isNomade,
    required this.distanceMax,
    required this.onMobiliteChanged,
    required this.onDistanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Votre mode\nd\'élevage ?',
            style: NexaTheme.displayM.copyWith(fontSize: 32),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text('Cela détermine comment NEXA vous guide.',
            style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 32),

          // Sédentaire
          GestureDetector(
            onTap: () => onMobiliteChanged(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: !isNomade
                    ? NexaTheme.vert.withOpacity(0.12)
                    : NexaTheme.blanc.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !isNomade
                      ? NexaTheme.vert.withOpacity(0.5)
                      : NexaTheme.blanc.withOpacity(0.08),
                  width: !isNomade ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  const Text('🏡', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sédentaire',
                          style: NexaTheme.titleL.copyWith(
                            color: !isNomade ? NexaTheme.vert : NexaTheme.blanc,
                          ),
                        ),
                        Text('Terrain fixe — gestion optimisée de vos zones',
                          style: NexaTheme.bodyS.copyWith(
                            color: NexaTheme.blanc.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNomade)
                    const Icon(Icons.check_circle_rounded, color: NexaTheme.vert, size: 22),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          const SizedBox(height: 12),

          // Nomade
          GestureDetector(
            onTap: () => onMobiliteChanged(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isNomade
                    ? NexaTheme.vert.withOpacity(0.12)
                    : NexaTheme.blanc.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNomade
                      ? NexaTheme.vert.withOpacity(0.5)
                      : NexaTheme.blanc.withOpacity(0.08),
                  width: isNomade ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  const Text('🐪', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nomade',
                          style: NexaTheme.titleL.copyWith(
                            color: isNomade ? NexaTheme.vert : NexaTheme.blanc,
                          ),
                        ),
                        Text('Navigation vers les meilleures zones NDVI',
                          style: NexaTheme.bodyS.copyWith(
                            color: NexaTheme.blanc.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isNomade)
                    const Icon(Icons.check_circle_rounded, color: NexaTheme.vert, size: 22),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          if (isNomade) ...[
            const SizedBox(height: 28),
            Text('Distance max que vous pouvez parcourir ?',
              style: NexaTheme.titleM,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 4),
            Text('NEXA cherchera uniquement dans ce rayon.',
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 20),
            Center(
              child: Text('${distanceMax.round()} km',
                style: NexaTheme.displayM.copyWith(color: NexaTheme.vert, fontSize: 48),
              ).animate().fadeIn(duration: 300.ms),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: NexaTheme.vert,
                inactiveTrackColor: NexaTheme.blanc.withOpacity(0.1),
                thumbColor: NexaTheme.vert,
                overlayColor: NexaTheme.vert.withOpacity(0.1),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: distanceMax,
                min: 10, max: 300, divisions: 29,
                onChanged: onDistanceChanged,
              ),
            ).animate().fadeIn(duration: 300.ms),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('10 km', style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
                  Text('300 km', style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}