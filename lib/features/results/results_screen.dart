import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/zone_service.dart';

class ResultsScreen extends StatefulWidget {
  final AnalysisResult result;
  final String? zoneAnalyseeId;
  final List<TerrainZone>? zones; // ✅ zones complètes si on vient d'une rotation
  const ResultsScreen({super.key, required this.result, this.zoneAnalyseeId, this.zones});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.delayed(600.ms, () {
      switch (widget.result.statut) {
        case PastureStatus.excellent:
          HapticFeedback.mediumImpact();
          break;
        case PastureStatus.critique:
          HapticFeedback.heavyImpact();
          break;
        default:
          HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.result.statut) {
      case PastureStatus.excellent: return NexaTheme.excellent;
      case PastureStatus.bon:       return NexaTheme.bon;
      case PastureStatus.attention: return NexaTheme.attention;
      case PastureStatus.critique:  return NexaTheme.critique;
    }
  }

  // ✅ Générer 4 zones depuis le résultat d'analyse
  // Quand l'éleveur arrive depuis /results sans polygone GPS
  // on crée 4 zones basées sur la surface et l'analyse

  List<TerrainZone> _genererZonesDepuisResultat() {
    final r = widget.result;
    final surfaceParZone = r.surfaceHa / 4;
    // ✅ Fix Bug 1 — utiliser la vraie zone analysée, pas toujours A
    final activeId = widget.zoneAnalyseeId ?? 'A';

    ZoneStatus statusPourZone(String id) {
      if (id != activeId) return ZoneStatus.attente; // ✅ Fix Bug 2 — toutes ATTENTE sauf la zone active
      switch (r.statut) {
        case PastureStatus.excellent:
        case PastureStatus.bon:       return ZoneStatus.active;
        case PastureStatus.attention: return ZoneStatus.finDeCycle;
        case PastureStatus.critique:  return ZoneStatus.epuisee;
      }
    }

    final ids = ['A', 'B', 'C', 'D'];
    return ids.map((id) => SavedZone(
      id: id,
      name: 'Zone $id',
      latitude: 0,
      longitude: 0,
      polygonLats: [],
      polygonLngs: [],
      surfaceHa: surfaceParZone,
      status: statusPourZone(id),
      derniereAnalyse: id == activeId ? r : null,
      joursDisponibles: id == activeId ? r.joursDisponibles : 0,
      isNext: false,
      dateDebutPaturage: id == activeId ? DateTime.now() : null,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: NexaTheme.noir,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(r),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroStatus(
                result: r,
                statusColor: _statusColor,
                pulseController: _pulseController,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _MetricsGrid(result: r, statusColor: _statusColor)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.2, delay: 200.ms),

                const SizedBox(height: 20),

                _BiomassChart(result: r)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 300.ms),

                const SizedBox(height: 20),

                _ActionCard(result: r, statusColor: _statusColor)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms),

                const SizedBox(height: 20),

                _CarbonCard(result: r)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 500.ms),

                const SizedBox(height: 20),

                // ✅ Si on vient d'une rotation → zones complètes · sinon générer
                NexaButton(
                  label: 'Voir le plan de rotation →',
                  onTap: () {
                    final zones = widget.zones ?? _genererZonesDepuisResultat();
                    context.push('/rotation', extra: zones);
                  },
                ).animate().fadeIn(duration: 400.ms, delay: 550.ms),

                const SizedBox(height: 12),

                NexaButton(
                  label: 'Nouvelle analyse →',
                  onTap: () => context.go('/camera'),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _share(AnalysisResult r) {
    // TODO: Share.share(...)
  }
}

// ── WIDGETS ───────────────────────────────────────────────

class _HeroStatus extends StatelessWidget {
  final AnalysisResult result;
  final Color statusColor;
  final AnimationController pulseController;

  const _HeroStatus({
    required this.result,
    required this.statusColor,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [statusColor.withOpacity(0.15), NexaTheme.noir],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: pulseController,
              builder: (_, child) => Container(
                width: 120 + pulseController.value * 8,
                height: 120 + pulseController.value * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withOpacity(0.2 + pulseController.value * 0.1),
                    width: 1,
                  ),
                ),
                child: child,
              ),
              child: CircularPercentIndicator(
                radius: 56,
                lineWidth: 5,
                percent: result.qualitePct / 100,
                center: Text(
                  '${result.qualitePct.toInt()}%',
                  style: NexaTheme.displayM.copyWith(color: statusColor, fontSize: 28),
                ),
                progressColor: statusColor,
                backgroundColor: statusColor.withOpacity(0.1),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 1200,
              ),
            ),
            const SizedBox(height: 16),
            Text(result.statut.label,
              style: NexaTheme.titleL.copyWith(color: statusColor, fontSize: 22),
            ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
            Text(
              '${result.joursDisponibles} jours disponibles pour ${result.troupeauSize} ${result.espece}s',
              style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.55)),
            ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final AnalysisResult result;
  final Color statusColor;
  const _MetricsGrid({required this.result, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _MetricTile(label: 'GDM Biomasse', value: result.gdmG.toStringAsFixed(1), unit: 'g/m²', color: statusColor, highlight: true),
        _MetricTile(label: 'Surface tracée', value: result.surfaceHa.toStringAsFixed(2), unit: 'hectares', color: const Color(0xFF3B82F6), highlight: true),
        _MetricTile(label: 'Végétation verte', value: result.greenG.toStringAsFixed(1), unit: 'g/m²', color: NexaTheme.vert),
        _MetricTile(label: 'Trèfle', value: result.cloverG.toStringAsFixed(1), unit: 'g/m²', color: NexaTheme.or),
        _MetricTile(label: 'Matière morte', value: result.deadG.toStringAsFixed(1), unit: 'g/m²', color: NexaTheme.gris),
        _MetricTile(label: 'Score santé', value: result.scoreSante.toInt().toString(), unit: '/ 100', color: NexaTheme.vert),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final bool highlight;
  const _MetricTile({required this.label, required this.value, required this.unit, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      padding: const EdgeInsets.all(14),
      borderColor: highlight ? color.withOpacity(0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.45), fontSize: 9)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: NexaTheme.displayM.copyWith(color: highlight ? color : NexaTheme.blanc, fontSize: 26)),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(unit, style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4)))),
          ]),
        ],
      ),
    );
  }
}

class _BiomassChart extends StatelessWidget {
  final AnalysisResult result;
  const _BiomassChart({required this.result});

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexaEyebrow('Composition de la biomasse'),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: result.totalG * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const labels = ['Verte', 'Trèfle', 'Morte'];
                      return Text(labels[v.toInt()],
                        style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.4), fontSize: 9));
                    },
                  )),
                  leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: result.greenG, color: NexaTheme.vert, width: 28, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: result.cloverG, color: NexaTheme.or, width: 28, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: result.deadG, color: NexaTheme.blanc.withOpacity(0.2), width: 28, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final AnalysisResult result;
  final Color statusColor;
  const _ActionCard({required this.result, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor.withOpacity(0.15), statusColor.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(result.statut.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('ACTION RECOMMANDÉE', style: NexaTheme.label.copyWith(color: statusColor)),
        ]),
        const SizedBox(height: 10),
        Text(result.statut.action, style: NexaTheme.bodyL),
      ]),
    );
  }
}

class _CarbonCard extends StatelessWidget {
  final AnalysisResult result;
  const _CarbonCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      borderColor: NexaTheme.or.withOpacity(0.2),
      child: Row(children: [
        const Text('🌍', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NexaEyebrow('Crédit carbone potentiel'),
          const SizedBox(height: 6),
          Text('\$${result.creditCarboneUSD.toStringAsFixed(0)} / an',
            style: NexaTheme.displayM.copyWith(color: NexaTheme.or, fontSize: 24)),
          Text('${result.creditCarboneTonne.toStringAsFixed(1)} tCO₂ · ${result.surfaceHa.toStringAsFixed(1)} ha',
            style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4))),
        ])),
      ]),
    );
  }
}