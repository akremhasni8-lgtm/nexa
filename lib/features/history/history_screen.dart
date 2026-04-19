import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<AnalysisResult>('analyses');

    return ValueListenableBuilder(
      // ✅ Écoute les changements du box en temps réel
      valueListenable: box.listenable(),
      builder: (context, Box<AnalysisResult> box, _) {
        final analyses = box.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
          backgroundColor: NexaTheme.noir,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: NexaTheme.noir,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => context.pop(),
                ),
                title: Text('HISTORIQUE', style: NexaTheme.displayM.copyWith(fontSize: 22)),
                actions: [
                  if (analyses.isNotEmpty)
                    TextButton(
                      onPressed: () => _showClearDialog(context, box),
                      child: Text('Effacer', style: NexaTheme.bodyS.copyWith(color: NexaTheme.rouge)),
                    ),
                ],
              ),

              if (analyses.isEmpty)
                const SliverFillRemaining(child: _EmptyHistory())
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      if (analyses.length >= 2) ...[
                        _EvolutionChart(analyses: analyses)
                            .animate().fadeIn(duration: 500.ms),
                        const SizedBox(height: 24),
                      ],

                      _GlobalStats(analyses: analyses)
                          .animate().fadeIn(duration: 500.ms, delay: 100.ms),
                      const SizedBox(height: 24),

                      Text(
                        'TOUTES LES ANALYSES',
                        style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 12),

                      ...analyses.asMap().entries.map((entry) {
                        final i = entry.key;
                        final a = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryCard(
                            analysis: a,
                            onTap: () => context.push('/results', extra: a),
                          ).animate().fadeIn(
                            duration: 400.ms,
                            delay: Duration(milliseconds: 50 * i),
                          ),
                        );
                      }),

                      SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showClearDialog(BuildContext context, Box box) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NexaTheme.noir2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Effacer l\'historique', style: NexaTheme.titleL),
        content: Text(
          'Toutes vos analyses seront supprimées. Cette action est irréversible.',
          style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: NexaTheme.bodyM),
          ),
          TextButton(
            onPressed: () {
              box.clear();
              Navigator.pop(context);
            },
            child: Text('Effacer', style: NexaTheme.bodyM.copyWith(color: NexaTheme.rouge)),
          ),
        ],
      ),
    );
  }
}

// ── WIDGETS ───────────────────────────────────────────────

class _EvolutionChart extends StatelessWidget {
  final List<AnalysisResult> analyses;
  const _EvolutionChart({required this.analyses});

  @override
  Widget build(BuildContext context) {
    final reversed = analyses.reversed.toList();
    return NexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexaEyebrow('Évolution du score santé'),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(show: false),
                minY: 0, maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: reversed.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.scoreSante),
                    ).toList(),
                    isCurved: true,
                    color: NexaTheme.vert,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: NexaTheme.vert,
                        strokeWidth: 2,
                        strokeColor: NexaTheme.noir,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [NexaTheme.vert.withOpacity(0.2), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalStats extends StatelessWidget {
  final List<AnalysisResult> analyses;
  const _GlobalStats({required this.analyses});

  @override
  Widget build(BuildContext context) {
    final avgScore = analyses.isEmpty ? 0.0
        : analyses.map((a) => a.scoreSante).reduce((a, b) => a + b) / analyses.length;
    final totalCarbone = analyses.map((a) => a.creditCarboneUSD).fold(0.0, (a, b) => a + b);
    final excellents = analyses.where((a) => a.statut == PastureStatus.excellent).length;

    return Row(
      children: [
        Expanded(child: _StatMini('${avgScore.toInt()}', 'Score moyen', NexaTheme.vert)),
        const SizedBox(width: 10),
        Expanded(child: _StatMini('${analyses.length}', 'Analyses', const Color(0xFF3B82F6))),
        const SizedBox(width: 10),
        Expanded(child: _StatMini('\$${totalCarbone.toInt()}', 'Carbone/an', NexaTheme.or)),
        const SizedBox(width: 10),
        Expanded(child: _StatMini('$excellents', 'Excellentes', NexaTheme.excellent)),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatMini(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withOpacity(0.2),
      child: Column(
        children: [
          Text(value, style: NexaTheme.displayM.copyWith(color: color, fontSize: 20)),
          Text(
            label,
            style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.4), fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AnalysisResult analysis;
  final VoidCallback onTap;

  const _HistoryCard({required this.analysis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _color(analysis.statut);

    return GestureDetector(
      onTap: onTap,
      child: NexaCard(
        borderColor: statusColor.withOpacity(0.2),
        child: Row(
          children: [
            // Indicateur statut
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.zoneName ?? 'Zone du ${_date(analysis.timestamp)}',
                    style: NexaTheme.titleM,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${analysis.espece} · ${analysis.troupeauSize} têtes · ${analysis.surfaceHa.toStringAsFixed(1)} ha',
                    style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${analysis.joursDisponibles}j',
                    style: NexaTheme.titleM.copyWith(color: statusColor, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${analysis.scoreSante.toInt()}/100',
                  style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.35)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _color(PastureStatus s) {
    switch (s) {
      case PastureStatus.excellent: return NexaTheme.excellent;
      case PastureStatus.bon:       return NexaTheme.bon;
      case PastureStatus.attention: return NexaTheme.attention;
      case PastureStatus.critique:  return NexaTheme.critique;
    }
  }

  String _date(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📊', style: TextStyle(fontSize: 64, color: NexaTheme.blanc.withOpacity(0.1))),
          const SizedBox(height: 16),
          Text('Aucun historique', style: NexaTheme.titleL.copyWith(color: NexaTheme.blanc.withOpacity(0.3))),
          const SizedBox(height: 8),
          Text(
            'Vos analyses apparaîtront ici.',
            style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}