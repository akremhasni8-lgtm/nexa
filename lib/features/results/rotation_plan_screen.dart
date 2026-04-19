import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../../core/theme/app_theme.dart';
import '../../services/zone_service.dart';

class RotationPlanScreen extends StatefulWidget {
  final List<TerrainZone> zones;
  const RotationPlanScreen({super.key, required this.zones});
  @override
  State<RotationPlanScreen> createState() => _RotationPlanScreenState();
}

class _RotationPlanScreenState extends State<RotationPlanScreen> {
  late List<TerrainZone> _zones;

  @override
  void initState() {
    super.initState();
    _zones = List.from(widget.zones);
    _recalculerNextZone();
  }

  void _recalculerNextZone() {
    final next = ZoneService.prochaineZone(_zones, _zoneActive.id);
    if (next != null) {
      _zones = _zones.map((z) => z.copyWith(isNext: z.id == next.id)).toList();
    }
  }

  // ✅ Fix Bug 3 — cherche la vraie zone ACTIVE, pas forcément A
  TerrainZone get _zoneActive {
    final actives = _zones.where((z) => z.status == ZoneStatus.active);
    if (actives.isNotEmpty) return actives.first;
    final dispos = _zones.where((z) => z.status != ZoneStatus.epuisee);
    if (dispos.isNotEmpty) return dispos.first;
    return _zones.first;
  }

  TerrainZone get _zoneNext {
    final nexts = _zones.where((z) => z.isNext);
    if (nexts.isNotEmpty) return nexts.first;
    final autres = _zones.where((z) => z.id != _zoneActive.id && z.status != ZoneStatus.epuisee);
    if (autres.isNotEmpty) return autres.first;
    return _zones.last;
  }

  double get _surfaceTotal => _zones.fold(0.0, (s, z) => s + z.surfaceHa);
  Color get _statusColor => _zoneActive.couleur;

  void _effectuerTransition() {
    final fromId = _zoneActive.id;
    final toId   = _zoneNext.id;

    // ✅ Fix Bug 3 — appliquer la transition immédiatement
    setState(() {
      _zones = ZoneService.effectuerTransition(_zones, fromId, toId);
      _recalculerNextZone();
    });
    ZoneService.sauvegarderZones(_zones);

    // Naviguer vers la caméra pour analyser la nouvelle zone active
    // On passe zoneAnalyseeId pour que results_screen sache quelle zone analyser
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Text('📸', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text('Analysez ${_zoneActive.nom} maintenant →'),
      ]),
      backgroundColor: _zoneActive.couleur,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) context.push('/camera');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      appBar: AppBar(
        backgroundColor: NexaTheme.noir,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Plan de Rotation', style: NexaTheme.titleL.copyWith(fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Text('${_surfaceTotal.toStringAsFixed(1)} ha · ${_zones.length} zones',
                style: NexaTheme.label.copyWith(color: _statusColor)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _StatusBanner(zone: _zoneActive, surfaceTotal: _surfaceTotal)
              .animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 20),

          _SurfaceSummary(zones: _zones, surfaceTotal: _surfaceTotal)
              .animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 20),

          NexaEyebrow('État des ${_zones.length} sous-zones'),
          const SizedBox(height: 12),
          _ZonesTable(zones: _zones)
              .animate().fadeIn(duration: 500.ms, delay: 150.ms),
          const SizedBox(height: 20),

          NexaEyebrow('Prochain déplacement'),
          const SizedBox(height: 12),
          _NextMoveCard(zoneActive: _zoneActive, zoneNext: _zoneNext)
              .animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 20),

          _AdviceCard(zone: _zoneActive)
              .animate().fadeIn(duration: 400.ms, delay: 250.ms),
          const SizedBox(height: 24),

          if (_zones.any((z) => z.polygon.length >= 3))
            NexaButton(
              label: 'Voir ${_zoneNext.nom} sur la carte →',
              onTap: () => context.push('/map', extra: MapScreenArgs(
                zones: _zones, highlightZoneId: _zoneNext.id,
              )),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 12),

          _PasserZoneButton(
            zoneActive: _zoneActive,
            zoneNext: _zoneNext,
            onConfirmer: _effectuerTransition,
            onAnalyser: () => context.go('/camera'),
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

          const SizedBox(height: 12),

          NexaButton(
            label: 'Nouvelle analyse',
            onTap: () => context.go('/camera'),
            outlined: true,
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ]),
      ),
    );
  }
}

// ── STATUS BANNER ─────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final TerrainZone zone;
  final double surfaceTotal;
  const _StatusBanner({required this.zone, required this.surfaceTotal});

  @override
  Widget build(BuildContext context) {
    final c = zone.couleur;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withOpacity(0.15), c.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text(zone.status == ZoneStatus.active ? '🟢' : zone.emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(zone.nom, style: NexaTheme.titleL.copyWith(color: c, fontSize: 16)),
          const SizedBox(height: 2),
          Text(zone.status.label, style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.55))),
          if (zone.derniereAnalyse != null)
            Text('${zone.derniereAnalyse!.troupeauSize} ${zone.derniereAnalyse!.espece}s · ${surfaceTotal.toStringAsFixed(1)} ha total',
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.35), fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            zone.joursRestants > 0 ? '${zone.joursRestants}j' : '—',
            style: NexaTheme.displayM.copyWith(color: c, fontSize: 28),
          ),
          Text('restants', style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.35), fontSize: 9)),
        ]),
      ]),
    );
  }
}

// ── SURFACE SUMMARY ───────────────────────────────────────

class _SurfaceSummary extends StatelessWidget {
  final List<TerrainZone> zones;
  final double surfaceTotal;
  const _SurfaceSummary({required this.zones, required this.surfaceTotal});

  @override
  Widget build(BuildContext context) {
    final spz = surfaceTotal / zones.length;
    return NexaCard(
      child: Column(children: [
        NexaEyebrow('Terrain divisé en ${zones.length} sous-zones'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SI('📐', 'Total', '${surfaceTotal.toStringAsFixed(1)} ha', NexaTheme.vert)),
          _VD(),
          Expanded(child: _SI('🔲', 'Par zone', '${spz.toStringAsFixed(1)} ha', const Color(0xFF3B82F6))),
          _VD(),
          Expanded(child: _SI('🔄', 'Cycles', '${zones.length} rot.', NexaTheme.or)),
        ]),
        const SizedBox(height: 14),
        Row(children: zones.map((z) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: z.couleur.withOpacity(0.2), borderRadius: BorderRadius.circular(6),
                border: Border.all(color: z.couleur.withOpacity(0.5)),
              ),
              child: Center(child: Text(z.id, style: NexaTheme.label.copyWith(color: z.couleur, fontSize: 11))),
            ),
          ),
        )).toList()),
      ]),
    );
  }
}

class _SI extends StatelessWidget {
  final String icon, label, value; final Color color;
  const _SI(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 4),
    Text(label, style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.4), fontSize: 9)),
    const SizedBox(height: 2),
    Text(value, style: NexaTheme.bodyS.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
  ]);
}

class _VD extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: NexaTheme.blanc.withOpacity(0.08));
}

// ── TABLEAU DES ZONES ─────────────────────────────────────

class _ZonesTable extends StatelessWidget {
  final List<TerrainZone> zones;
  const _ZonesTable({required this.zones});

  TextStyle get _hs => NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3), fontSize: 9, letterSpacing: 1.5);

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(color: Color(0xFF0D1A0D), borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            const SizedBox(width: 30),
            Expanded(flex: 4, child: Text('ZONE', style: _hs)),
            Expanded(flex: 3, child: Text('STATUT', style: _hs, textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('JOURS', style: _hs, textAlign: TextAlign.right)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF1A2A1A)),
        ...zones.asMap().entries.map((e) {
          final z = e.value;
          final isLast = e.key == zones.length - 1;
          final isHL = z.status == ZoneStatus.active || z.isNext;
          return Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: isHL ? z.couleur.withOpacity(0.07) : Colors.transparent,
                borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(14)) : null,
              ),
              child: Row(children: [
                SizedBox(width: 30, child: Text(
                  z.status == ZoneStatus.active ? '🟢' : z.emoji,
                  style: const TextStyle(fontSize: 16),
                )),
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(z.nom,
                      style: NexaTheme.titleL.copyWith(
                        fontSize: 12,
                        color: z.status == ZoneStatus.active ? z.couleur : NexaTheme.blanc,
                      ), overflow: TextOverflow.ellipsis)),
                    if (z.status == ZoneStatus.active) ...[
                      const SizedBox(width: 4),
                      Container(width: 5, height: 5, decoration: BoxDecoration(
                        shape: BoxShape.circle, color: z.couleur,
                        boxShadow: [BoxShadow(color: z.couleur.withOpacity(0.6), blurRadius: 3)],
                      )),
                    ],
                    if (z.isNext) ...[
                      const SizedBox(width: 4),
                      Text('→', style: TextStyle(color: z.couleur, fontSize: 9)),
                    ],
                  ]),
                  Text(z.status.description,
                    style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.3), fontSize: 8),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Expanded(flex: 3, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: z.couleur.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: z.couleur.withOpacity(0.25)),
                  ),
                  child: Text(z.status.label,
                    style: NexaTheme.label.copyWith(color: z.couleur, fontSize: 7),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
                // ✅ Fix Bug 4 — jours corrects selon le statut
                Expanded(flex: 2, child: Text(
                  z.status == ZoneStatus.attente
                      ? '—'
                      : z.status == ZoneStatus.repos
                          ? '${z.joursDisponibles}j 💤'
                          : z.joursRestants > 0
                              ? '${z.joursRestants}j'
                              : '📸',
                  style: NexaTheme.bodyS.copyWith(
                    color: z.status == ZoneStatus.repos ? const Color(0xFF3B82F6) : z.couleur,
                    fontWeight: FontWeight.bold, fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                )),
              ]),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF1A2A1A)),
          ]);
        }),
      ]),
    );
  }
}

// ── NEXT MOVE CARD ────────────────────────────────────────

class _NextMoveCard extends StatelessWidget {
  final TerrainZone zoneActive;
  final TerrainZone zoneNext;
  const _NextMoveCard({required this.zoneActive, required this.zoneNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [zoneNext.couleur.withOpacity(0.12), zoneNext.couleur.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zoneNext.couleur.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _MoveBox(zone: zoneActive, label: 'ACTUELLE')),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, color: zoneNext.couleur, size: 22)),
          Expanded(child: _MoveBox(zone: zoneNext, label: 'PROCHAINE')),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NexaTheme.vert.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NexaTheme.vert.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(zoneActive.status.actionLabel,
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.65), fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

class _MoveBox extends StatelessWidget {
  final TerrainZone zone; final String label;
  const _MoveBox({required this.zone, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: zone.couleur.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: zone.couleur.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(zone.status == ZoneStatus.active ? '🟢' : zone.emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(zone.nom, style: NexaTheme.titleL.copyWith(color: zone.couleur, fontSize: 14)),
      Text(
        zone.joursRestants > 0 ? '${zone.joursRestants}j' : zone.status == ZoneStatus.attente ? 'à analyser' : '—',
        style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.4), fontSize: 9),
      ),
      Text(label, style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.2), fontSize: 8)),
    ]),
  );
}

// ── ADVICE CARD ───────────────────────────────────────────

class _AdviceCard extends StatelessWidget {
  final TerrainZone zone;
  const _AdviceCard({required this.zone});

  List<Map<String, String>> get _conseils {
    switch (zone.status) {
      case ZoneStatus.active:
        return [
          {'icon': '🌿', 'text': 'Respectez la rotation pour maintenir la qualité du pâturage.'},
          {'icon': '📅', 'text': 'Planifiez le déplacement avant la fin du cycle.'},
          {'icon': '💧', 'text': 'Vérifiez l\'accès à l\'eau pour le troupeau.'},
        ];
      case ZoneStatus.finDeCycle:
        return [
          {'icon': '⚠️', 'text': 'Biomasse faible — préparez le déplacement maintenant.'},
          {'icon': '🔄', 'text': 'Déplacez le troupeau sur la prochaine zone disponible.'},
          {'icon': '🌱', 'text': 'Laissez cette zone se régénérer minimum 3 semaines.'},
        ];
      case ZoneStatus.epuisee:
        return [
          {'icon': '🆘', 'text': 'Zone épuisée — quittez immédiatement pour préserver le sol.'},
          {'icon': '🔴', 'text': 'Ne revenez pas avant 45 jours minimum.'},
          {'icon': '📊', 'text': 'Analysez la prochaine zone avant d\'y déplacer le troupeau.'},
        ];
      default:
        return [
          {'icon': '📸', 'text': 'Analysez régulièrement pour des données précises.'},
          {'icon': '🔄', 'text': 'Continuez la rotation pour maintenir la santé des pâturages.'},
          {'icon': '📅', 'text': 'Respectez les temps de repos de chaque zone.'},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return NexaCard(
      borderColor: zone.couleur.withOpacity(0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(zone.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('CONSEILS', style: NexaTheme.label.copyWith(color: zone.couleur)),
        ]),
        const SizedBox(height: 12),
        ..._conseils.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['icon']!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(c['text']!,
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.65), fontSize: 12))),
          ]),
        )),
      ]),
    );
  }
}

// ── BOUTON PASSER À LA ZONE SUIVANTE ─────────────────────

class _PasserZoneButton extends StatelessWidget {
  final TerrainZone zoneActive;
  final TerrainZone zoneNext;
  final VoidCallback onConfirmer;
  final VoidCallback onAnalyser;

  const _PasserZoneButton({
    required this.zoneActive,
    required this.zoneNext,
    required this.onConfirmer,
    required this.onAnalyser,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmer(context),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            zoneNext.couleur.withOpacity(0.15),
            zoneNext.couleur.withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: zoneNext.couleur.withOpacity(0.4)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🔄', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(child: Text(
                'PASSER À ${zoneNext.nom.toUpperCase()}',
                style: NexaTheme.label.copyWith(color: zoneNext.couleur),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
            const SizedBox(height: 6),
            Text('${zoneActive.nom} → REPOS  ·  ${zoneNext.nom} → ACTIVE',
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.55), fontSize: 12)),
            const SizedBox(height: 3),
            Text('Vous analyserez ${zoneNext.nom} immédiatement après la transition',
              style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.3), fontSize: 10)),
          ])),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: zoneNext.couleur.withOpacity(0.15), shape: BoxShape.circle,
              border: Border.all(color: zoneNext.couleur.withOpacity(0.4)),
            ),
            child: Icon(Icons.arrow_forward_rounded, color: zoneNext.couleur, size: 20),
          ),
        ]),
      ),
    );
  }

  void _confirmer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1A0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Text(zoneNext.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Text('Confirmer le passage', style: NexaTheme.titleL.copyWith(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DR(emoji: '😴', text: '${zoneActive.nom} → REPOS (${(zoneActive.joursDisponibles * 0.75).ceil()}j de régénération)'),
          const SizedBox(height: 8),
          _DR(emoji: '🟢', text: '${zoneNext.nom} → ACTIVE'),
          const SizedBox(height: 8),
          _DR(emoji: '📸', text: 'Vous allez analyser ${zoneNext.nom} maintenant'),
          const SizedBox(height: 8),
          _DR(emoji: '💾', text: 'Transition sauvegardée · tableau mis à jour'),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.4))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirmer(); // met à jour le tableau
              // onConfirmer navigue vers /camera automatiquement
            },
            child: Text('Confirmer + Analyser →',
              style: NexaTheme.bodyM.copyWith(color: zoneNext.couleur, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DR extends StatelessWidget {
  final String emoji, text;
  const _DR({required this.emoji, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 8),
    Expanded(child: Text(text,
      style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.65), fontSize: 12))),
  ]);
}