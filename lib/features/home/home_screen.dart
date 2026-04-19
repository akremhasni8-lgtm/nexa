import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

// ── WEATHER MODEL ─────────────────────────────────────────
class WeatherData {
  final double temp;
  final String description;
  final String icon;
  final String city;
  final int humidity;
  final double windSpeed;

  const WeatherData({
    required this.temp,
    required this.description,
    required this.icon,
    required this.city,
    required this.humidity,
    required this.windSpeed,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnim;
  bool _sidebarOpen = false;

  // Météo
  WeatherData? _weather;
  bool _weatherLoading = true;
  String? _weatherError;

  static const _weatherKey = 'd9ab783b88b02dd6ef6a4aea6f053a12';

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _sidebarAnim = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
    );
    _fetchWeather();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      // Obtenir la position GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (!serviceEnabled || permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Fallback : Niamey (Niger) si pas de GPS
        position = Position(
          latitude: 13.5137,
          longitude: 2.1098,
          timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0,
          speed: 0, speedAccuracy: 0, altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      } else {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
      }

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${position.latitude}&lon=${position.longitude}'
        '&appid=$_weatherKey&units=metric&lang=fr',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _weather = WeatherData(
              temp: (data['main']['temp'] as num).toDouble(),
              description: data['weather'][0]['description'] as String,
              icon: data['weather'][0]['icon'] as String,
              city: data['name'] as String,
              humidity: data['main']['humidity'] as int,
              windSpeed: (data['wind']['speed'] as num).toDouble(),
            );
            _weatherLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _weatherLoading = false; _weatherError = 'Indisponible'; });
      }
    } catch (e) {
      if (mounted) setState(() { _weatherLoading = false; _weatherError = 'Indisponible'; });
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
    _sidebarOpen ? _sidebarController.forward() : _sidebarController.reverse();
  }

  void _closeSidebar() {
    if (_sidebarOpen) {
      setState(() => _sidebarOpen = false);
      _sidebarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysesBox  = Hive.box<AnalysisResult>('analyses');
    final profileBox   = Hive.box<EleveurProfile>('profile');
    final profile      = profileBox.values.isNotEmpty ? profileBox.values.first : null;
    final analyses     = analysesBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastAnalysis = analyses.isNotEmpty ? analyses.first : null;
    final isNomade     = profile?.isNomade ?? false;

    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(
        children: [

          // ── CONTENU PRINCIPAL ──────────────────────────
          GestureDetector(
            onTap: _closeSidebar,
            child: AnimatedBuilder(
              animation: _sidebarAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_sidebarAnim.value * 260, 0),
                child: child,
              ),
              child: _MainContent(
                profile: profile,
                lastAnalysis: lastAnalysis,
                analyses: analyses,
                isNomade: isNomade,
                weather: _weather,
                weatherLoading: _weatherLoading,
                weatherError: _weatherError,
                onMenuTap: _toggleSidebar,
                onScanTap: () => context.push('/camera'),
                onRefreshWeather: _fetchWeather,
              ),
            ),
          ),

          // ── OVERLAY SIDEBAR ───────────────────────────
          if (_sidebarOpen)
            GestureDetector(
              onTap: _closeSidebar,
              child: AnimatedBuilder(
                animation: _sidebarAnim,
                builder: (_, __) => Container(
                  color: Colors.black.withOpacity(0.5 * _sidebarAnim.value),
                ),
              ),
            ),

          // ── SIDEBAR ───────────────────────────────────
          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(-260 * (1 - _sidebarAnim.value), 0),
              child: child,
            ),
            child: _Sidebar(
              profile: profile,
              isNomade: isNomade,
              onClose: _closeSidebar,
            ),
          ),
        ],
      ),
    );
  }
}

// ── CONTENU PRINCIPAL ─────────────────────────────────────

class _MainContent extends StatelessWidget {
  final EleveurProfile? profile;
  final AnalysisResult? lastAnalysis;
  final List<AnalysisResult> analyses;
  final bool isNomade;
  final WeatherData? weather;
  final bool weatherLoading;
  final String? weatherError;
  final VoidCallback onMenuTap;
  final VoidCallback onScanTap;
  final VoidCallback onRefreshWeather;

  const _MainContent({
    required this.profile,
    required this.lastAnalysis,
    required this.analyses,
    required this.isNomade,
    required this.weather,
    required this.weatherLoading,
    required this.weatherError,
    required this.onMenuTap,
    required this.onScanTap,
    required this.onRefreshWeather,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = analyses.isEmpty;

    return CustomScrollView(
      slivers: [

        // ── HEADER ────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          floating: false,
          pinned: true,
          backgroundColor: NexaTheme.noir,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [NexaTheme.vertDeep, NexaTheme.noir],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Menu
                          GestureDetector(
                            onTap: onMenuTap,
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: NexaTheme.blanc.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: NexaTheme.blanc.withOpacity(0.1),
                                ),
                              ),
                              child: Icon(
                                Icons.menu_rounded,
                                color: NexaTheme.blanc.withOpacity(0.8),
                                size: 20,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-16, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/logo-nexa.png',
                                  height: 44,
                                  width: 44,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'NEXA',
                                  style: NexaTheme.displayL.copyWith(
                                    color: NexaTheme.vert,
                                    fontSize: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showProfileSheet(context, profile),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: NexaTheme.vert.withOpacity(0.2),
                              child: Text(
                                profile?.nom.isNotEmpty == true
                                    ? profile!.nom[0].toUpperCase()
                                    : AuthService().currentUser?.email?[0].toUpperCase() ?? '?',
                                style: NexaTheme.titleM.copyWith(color: NexaTheme.vert),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (profile?.nom?.isNotEmpty ?? false)
                            ? 'Bonjour, ${profile!.nom} 👋'
                            : 'Bienvenue sur NEXA 👋',
                        style: NexaTheme.bodyL,
                      ),
                      Text(
                        isEmpty
                            ? 'Faites votre première analyse'
                            : _subtitle(lastAnalysis),
                        style: NexaTheme.bodyM.copyWith(
                          color: NexaTheme.blanc.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ── MÉTÉO ──────────────────────────────────
              _WeatherCard(
                weather: weather,
                loading: weatherLoading,
                error: weatherError,
                onRefresh: onRefreshWeather,
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 14),

              // ── BANNER NOMADE ──────────────────────────
              if (isNomade) ...[
                _NomadeBanner().animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 14),
              ],

              // ── SCORE SANTÉ ───────────────────────────
              if (lastAnalysis != null) ...[
                _ScoreSanteTerresCard(analysis: lastAnalysis!)
                    .animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
                const SizedBox(height: 14),
              ],

              // ── CTA ANALYSER ──────────────────────────
              _AnalyzeButton(onTap: onScanTap)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: 0.2, delay: 100.ms),

              const SizedBox(height: 20),

              // ── TIP ANIMÉ (si vide) ───────────────────
              if (isEmpty) ...[
                _AnimatedTipCard()
                    .animate().fadeIn(duration: 600.ms, delay: 150.ms),
                const SizedBox(height: 20),
              ],

              // ── HISTORIQUE ────────────────────────────
              if (analyses.isNotEmpty) ...[
                Text(
                  'ANALYSES RÉCENTES',
                  style: NexaTheme.label.copyWith(
                    color: NexaTheme.gris.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                ...analyses.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnalysisHistoryTile(
                    analysis: a,
                    onTap: () => context.push('/results', extra: a),
                  ).animate().fadeIn(duration: 400.ms),
                )),
                TextButton(
                  onPressed: () => context.push('/history'),
                  child: Text(
                    'Voir tout l\'historique →',
                    style: NexaTheme.bodyS.copyWith(color: NexaTheme.vert),
                  ),
                ),
              ] else ...[
                _EmptyState()
                    .animate().fadeIn(duration: 600.ms, delay: 300.ms),
              ],

              // ── BANDE PARTENAIRES RETIRÉE ─────────────────────
              const SizedBox(height: 24),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ]),
          ),
        ),
      ],
    );
  }

  String _subtitle(AnalysisResult? last) {
    if (last == null) return 'Faites votre première analyse';
    final j = last.joursDisponibles;
    if (j >= 7) return '✅ Dernière zone : $j jours disponibles';
    if (j >= 3) return '⚠️ Attention : seulement $j jours restants';
    return '🔴 Zone épuisée — déplacez votre troupeau';
  }

  void _showProfileSheet(BuildContext context, EleveurProfile? profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexaTheme.noir2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileSheet(profile: profile),
    );
  }
}

// ── MÉTÉO CARD ────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  const _WeatherCard({
    required this.weather,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  String _weatherEmoji(String icon) {
    if (icon.startsWith('01')) return '☀️';
    if (icon.startsWith('02')) return '🌤️';
    if (icon.startsWith('03') || icon.startsWith('04')) return '☁️';
    if (icon.startsWith('09') || icon.startsWith('10')) return '🌧️';
    if (icon.startsWith('11')) return '⛈️';
    if (icon.startsWith('13')) return '❄️';
    if (icon.startsWith('50')) return '🌫️';
    return '🌡️';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      borderColor: NexaTheme.vert.withOpacity(0.15),
      padding: const EdgeInsets.all(16),
      child: loading
          ? Row(
              children: [
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NexaTheme.vert,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Chargement météo...',
                  style: NexaTheme.bodyS.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.4),
                  ),
                ),
              ],
            )
          : error != null
              ? Row(
                  children: [
                    Text('🌡️', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Météo indisponible',
                        style: NexaTheme.bodyS.copyWith(
                          color: NexaTheme.blanc.withOpacity(0.35),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRefresh,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: NexaTheme.vert.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text(
                      _weatherEmoji(weather!.icon),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${weather!.temp.round()}°C',
                                style: NexaTheme.displayM.copyWith(
                                  color: NexaTheme.blanc,
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _capitalize(weather!.description),
                                  style: NexaTheme.bodyS.copyWith(
                                    color: NexaTheme.blanc.withOpacity(0.5),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${weather!.city}',
                            style: NexaTheme.bodyS.copyWith(
                              color: NexaTheme.vert.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Humidité + vent
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop_rounded,
                                size: 11,
                                color: NexaTheme.blanc.withOpacity(0.35)),
                            const SizedBox(width: 3),
                            Text(
                              '${weather!.humidity}%',
                              style: NexaTheme.label.copyWith(
                                color: NexaTheme.blanc.withOpacity(0.35),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.air_rounded,
                                size: 11,
                                color: NexaTheme.blanc.withOpacity(0.35)),
                            const SizedBox(width: 3),
                            Text(
                              '${weather!.windSpeed.round()} m/s',
                              style: NexaTheme.label.copyWith(
                                color: NexaTheme.blanc.withOpacity(0.35),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

// ── TIP ANIMÉ ─────────────────────────────────────────────

class _AnimatedTipCard extends StatefulWidget {
  @override
  State<_AnimatedTipCard> createState() => _AnimatedTipCardState();
}

class _AnimatedTipCardState extends State<_AnimatedTipCard> {
  int _tipIndex = 0;

  static const _tips = [
    _Tip(
      icon: '📸',
      step: 'Étape 1',
      title: 'Prenez une photo de l\'herbe',
      desc: 'Photographiez le pâturage en vous plaçant à 1–2 m de hauteur, en plein jour. Évitez l\'ombre directe.',
    ),
    _Tip(
      icon: '🗺️',
      step: 'Étape 2',
      title: 'Délimitez votre zone',
      desc: 'Sur la carte, tracez le périmètre de votre pâturage. NEXA calcule automatiquement la surface en hectares.',
    ),
    _Tip(
      icon: '🧠',
      step: 'Étape 3',
      title: 'L\'IA analyse la biomasse',
      desc: 'Notre modèle EfficientNet-B2 (86% de précision) estime la quantité d\'herbe disponible pour votre troupeau.',
    ),
    _Tip(
      icon: '📋',
      step: 'Étape 4',
      title: 'Recevez votre plan',
      desc: 'NEXA vous dit combien de jours ce pâturage peut nourrir votre troupeau et quand le déplacer.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_tipIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COMMENT COMMENCER',
              style: NexaTheme.label.copyWith(
                color: NexaTheme.gris.withOpacity(0.7),
              ),
            ),
            // Indicateurs
            Row(
              children: List.generate(_tips.length, (i) {
                final isActive = i == _tipIndex;
                return GestureDetector(
                  onTap: () => setState(() => _tipIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 5),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? NexaTheme.vert
                          : NexaTheme.blanc.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: NexaCard(
            key: ValueKey(_tipIndex),
            borderColor: NexaTheme.vert.withOpacity(0.2),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: NexaTheme.vert.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: NexaTheme.vert.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tip.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.step,
                            style: NexaTheme.label.copyWith(
                              color: NexaTheme.vert,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            tip.title,
                            style: NexaTheme.titleM.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tip.desc,
                  style: NexaTheme.bodyS.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.5),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_tipIndex > 0)
                      GestureDetector(
                        onTap: () => setState(() => _tipIndex--),
                        child: Text(
                          '← Précédent',
                          style: NexaTheme.bodyS.copyWith(
                            color: NexaTheme.blanc.withOpacity(0.3),
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    GestureDetector(
                      onTap: () {
                        if (_tipIndex < _tips.length - 1) {
                          setState(() => _tipIndex++);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: NexaTheme.vert.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: NexaTheme.vert.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _tipIndex < _tips.length - 1
                              ? 'Suivant →'
                              : '✅ C\'est compris !',
                          style: NexaTheme.bodyS.copyWith(
                            color: NexaTheme.vert,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tip {
  final String icon, step, title, desc;
  const _Tip({
    required this.icon,
    required this.step,
    required this.title,
    required this.desc,
  });
}

// ── BANDE PARTENAIRES SUPPRIMÉE ───────────────────────────

// ── BANNER NOMADE ─────────────────────────────────────────

class _NomadeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/ndvi'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.15),
              NexaTheme.noir2,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.satellite_alt_rounded,
                color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zones végétation disponibles',
                    style: NexaTheme.titleM.copyWith(
                      color: const Color(0xFF10B981), fontSize: 13,
                    ),
                  ),
                  Text(
                    'Trouver la meilleure zone NDVI proche de vous',
                    style: NexaTheme.bodyS.copyWith(
                      color: NexaTheme.blanc.withOpacity(0.4), fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF10B981), size: 14),
          ],
        ),
      ),
    );
  }
}

// ── SCORE SANTÉ ───────────────────────────────────────────

class _ScoreSanteTerresCard extends StatelessWidget {
  final AnalysisResult analysis;
  const _ScoreSanteTerresCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final score = analysis.scoreSante;
    final color = _scoreColor(score);

    return NexaCard(
      borderColor: color.withOpacity(0.3),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 45,
            lineWidth: 6,
            percent: score / 100,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${score.toInt()}',
                  style: NexaTheme.displayM.copyWith(color: color, fontSize: 24),
                ),
                Text('/100', style: NexaTheme.label.copyWith(color: NexaTheme.gris)),
              ],
            ),
            progressColor: color,
            backgroundColor: color.withOpacity(0.1),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NexaEyebrow('Score santé des terres'),
                const SizedBox(height: 8),
                Text(analysis.statut.label,
                  style: NexaTheme.titleM.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  '${analysis.joursDisponibles} jours · ${analysis.surfaceHa.toStringAsFixed(1)} ha',
                  style: NexaTheme.bodyS.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~\$${analysis.creditCarboneUSD.toStringAsFixed(0)}/an · carbone',
                  style: NexaTheme.bodyS.copyWith(color: NexaTheme.or),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return NexaTheme.excellent;
    if (score >= 45) return NexaTheme.bon;
    if (score >= 25) return NexaTheme.attention;
    return NexaTheme.critique;
  }
}

// ── BOUTON ANALYSER ───────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AnalyzeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NexaTheme.vertDeep, Color(0xFF2D6A4F)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NexaTheme.vert.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: NexaTheme.vert.withOpacity(0.2),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: NexaTheme.vert.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: NexaTheme.vert.withOpacity(0.5)),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: NexaTheme.vert, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANALYSER UN PÂTURAGE',
                      style: NexaTheme.titleL.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Photo + GPS → Plan de rotation',
                      style: NexaTheme.bodyS.copyWith(
                        color: NexaTheme.blanc.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: NexaTheme.vert, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HISTORIQUE TILE ───────────────────────────────────────

class _AnalysisHistoryTile extends StatelessWidget {
  final AnalysisResult analysis;
  final VoidCallback onTap;
  const _AnalysisHistoryTile({required this.analysis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(analysis.statut);
    return GestureDetector(
      onTap: onTap,
      child: NexaCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48, height: 48,
                color: NexaTheme.vertDeep,
                child: const Icon(Icons.grass_rounded, color: NexaTheme.vert),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.zoneName ?? 'Zone analysée',
                    style: NexaTheme.titleM.copyWith(fontSize: 14),
                  ),
                  Text(
                    _formatDate(analysis.timestamp),
                    style: NexaTheme.bodyS.copyWith(
                      color: NexaTheme.blanc.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                '${analysis.joursDisponibles}j',
                style: NexaTheme.titleM.copyWith(color: color, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PastureStatus s) {
    switch (s) {
      case PastureStatus.excellent: return NexaTheme.excellent;
      case PastureStatus.bon:       return NexaTheme.bon;
      case PastureStatus.attention: return NexaTheme.attention;
      case PastureStatus.critique:  return NexaTheme.critique;
    }
  }

  String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
}

// ── EMPTY STATE ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text('🌾', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Aucune analyse encore',
              style: NexaTheme.titleM.copyWith(
                color: NexaTheme.blanc.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Appuyez sur "Analyser" pour\ncommencer votre première analyse.',
              style: NexaTheme.bodyS.copyWith(
                color: NexaTheme.blanc.withOpacity(0.2),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── SIDEBAR ───────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final EleveurProfile? profile;
  final bool isNomade;
  final VoidCallback onClose;

  const _Sidebar({
    required this.profile,
    required this.isNomade,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Container(
      width: 260,
      height: double.infinity,
      decoration: BoxDecoration(
        color: NexaTheme.noir2,
        border: Border(
          right: BorderSide(color: NexaTheme.vert.withOpacity(0.12)),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: NexaTheme.vert.withOpacity(0.15),
                    child: Text(
                      user?.email?.isNotEmpty == true
                          ? user!.email![0].toUpperCase()
                          : '?',
                      style: NexaTheme.titleL.copyWith(color: NexaTheme.vert),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.nom ?? 'Éleveur',
                          style: NexaTheme.titleM,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isNomade ? '🐪 Nomade' : '🏡 Sédentaire',
                          style: NexaTheme.bodyS.copyWith(
                            color: NexaTheme.vert.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: NexaTheme.blanc.withOpacity(0.06)),
            const SizedBox(height: 8),

            _SidebarItem(icon: Icons.home_rounded,         label: 'Accueil',          onTap: () { onClose(); context.go('/'); }),
            _SidebarItem(icon: Icons.camera_alt_rounded,   label: 'Analyser',         color: NexaTheme.vert,             onTap: () { onClose(); context.push('/camera'); }),
            _SidebarItem(icon: Icons.map_outlined,         label: 'Carte',            color: const Color(0xFF3B82F6),    onTap: () { onClose(); context.push('/map'); }),
            _SidebarItem(icon: Icons.history_rounded,      label: 'Historique',       color: NexaTheme.or,               onTap: () { onClose(); context.push('/history'); }),
            if (isNomade)
              _SidebarItem(icon: Icons.satellite_alt_rounded, label: 'Zones végétation', color: const Color(0xFF10B981), badge: 'NDVI', onTap: () { onClose(); context.push('/ndvi'); }),
            _SidebarItem(icon: Icons.eco_outlined,         label: 'Crédits carbone',  color: NexaTheme.or,               onTap: () {}),

            const Spacer(),
            Divider(color: NexaTheme.blanc.withOpacity(0.06)),
            _SidebarItem(
              icon: Icons.logout_rounded,
              label: 'Se déconnecter',
              color: Colors.red.shade400,
              onTap: () async {
                onClose();
                await AuthService().signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final String? badge;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NexaTheme.blanc.withOpacity(0.7);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: NexaTheme.titleM.copyWith(
                  color: c, fontSize: 14, fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: NexaTheme.vert.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: NexaTheme.vert.withOpacity(0.3)),
                ),
                child: Text(
                  badge!,
                  style: NexaTheme.label.copyWith(color: NexaTheme.vert, fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── PROFILE SHEET ─────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  final EleveurProfile? profile;
  const _ProfileSheet({this.profile});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: NexaTheme.blanc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 28,
            backgroundColor: NexaTheme.vert.withOpacity(0.15),
            child: Text(
              user?.email?.isNotEmpty == true
                  ? user!.email![0].toUpperCase() : '?',
              style: NexaTheme.displayM.copyWith(color: NexaTheme.vert, fontSize: 24),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user?.email ?? 'Utilisateur',
            style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          Divider(color: NexaTheme.blanc.withOpacity(0.08)),
          const SizedBox(height: 12),
          _MenuButton(icon: Icons.person_outline_rounded, label: 'Profil',         onTap: () {}),
          const SizedBox(height: 8),
          _MenuButton(icon: Icons.settings_outlined,      label: 'Paramètres',     onTap: () {}),
          const SizedBox(height: 8),
          _MenuButton(
            icon: Icons.logout_rounded,
            label: 'Se déconnecter',
            color: Colors.red.shade400,
            onTap: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NexaTheme.blanc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: NexaTheme.titleM.copyWith(color: c))),
            Icon(Icons.arrow_forward_ios_rounded, color: c.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }
}