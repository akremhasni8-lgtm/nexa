import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'dart:ui' as ui;
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/ndvi_service.dart';

class NdviScreen extends StatefulWidget {
  const NdviScreen({super.key});

  @override
  State<NdviScreen> createState() => _NdviScreenState();
}

class _NdviScreenState extends State<NdviScreen> {
  final MapController _mapController = MapController();

  LatLng? _position;
  double  _rayonKm   = 50;
  bool    _isLoading = false;
  String  _loadingStep = '';
  int     _loadingProgress = 0; // 0-10 points traités
  List<NdviZone> _zones = [];
  NdviZone? _selected;
  String? _erreur;

  int    _troupeauSize = 25;
  String _espece = 'Vache';

  @override
  void initState() {
    super.initState();
    _chargerProfil();
    _localiser();
  }

  void _chargerProfil() {
    final box = Hive.box<EleveurProfile>('profile');
    if (box.values.isNotEmpty) {
      final p = box.values.first;
      setState(() { _troupeauSize = p.troupeauSize; _espece = p.espece; });
    }
  }

  Future<void> _localiser() async {
    setState(() {
      _isLoading = true;
      _loadingStep = 'Localisation GPS...';
      _loadingProgress = 0;
    });
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _position = LatLng(pos.latitude, pos.longitude);
        _loadingStep = 'Position GPS obtenue';
      });
      _mapController.move(_position!, 9);
      await _rechercher();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _erreur = 'Impossible d\'obtenir votre position GPS.';
      });
    }
  }

  Future<void> _rechercher() async {
    if (_position == null) return;
    setState(() {
      _isLoading  = true;
      _zones      = [];
      _selected   = null;
      _erreur     = null;
      _loadingProgress = 0;
      _loadingStep = 'Vérification des zones terrestres...';
    });

    try {
      // On utilise un stream pour mettre à jour la progression
      setState(() => _loadingStep = 'Analyse satellite en cours (1/3)...');
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _loadingStep = 'Récupération données NASA MODIS (2/3)...'; _loadingProgress = 3; });

      final zones = await NdviService.rechercherAvecFallback(
        position: _position!,
        rayonKm: _rayonKm,
        nombrePoints: 8,
      );

      setState(() { _loadingProgress = 10; _loadingStep = 'Traitement terminé'; });
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        _zones     = zones;
        _isLoading = false;
        _erreur    = zones.isEmpty
            ? 'Aucune donnée disponible.\nVérifiez votre connexion internet.'
            : null;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _erreur    = 'Erreur réseau. Vérifiez votre connexion.';
      });
    }
  }

  Color _hexColor(String hex) =>
      Color(int.parse(hex.replaceAll('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(children: [
        _buildMap(),
        _buildTopBar(),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildSheet()),
        if (_isLoading) _buildLoader(),
      ]),
    );
  }

  // ── CARTE ─────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _position ?? const LatLng(14.5, -14.5),
        initialZoom: 9,
        onTap: (_, __) => setState(() => _selected = null),
      ),
      children: [
        // Fond satellite
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.nexa.app',
        ),

        // Overlay NDVI NASA GIBS (données vraies)
        TileLayer(
          urlTemplate: NdviService.gibsTileUrl(),
          userAgentPackageName: 'com.nexa.app',
        ),

        // Rayon de recherche — cercle simple fin
        if (_position != null)
          CircleLayer(circles: [
            CircleMarker(
              point: _position!,
              radius: _rayonKm * 1000,
              color: NexaTheme.vert.withOpacity(0.04),
              borderColor: NexaTheme.vert.withOpacity(0.35),
              borderStrokeWidth: 1,
              useRadiusInMeter: true,
            ),
          ]),

        // Zones NDVI — petits marqueurs pin propres
        if (_zones.isNotEmpty)
          MarkerLayer(
            markers: _zones.asMap().entries.map((e) {
              final z = e.value;
              final idx = e.key;
              final isSelected = _selected?.centre == z.centre;
              final color = _hexColor(z.qualite.couleurHex);
              return Marker(
                point: z.centre,
                width: isSelected ? 64 : 48,
                height: isSelected ? 72 : 56,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selected = isSelected ? null : z);
                    if (!isSelected) _mapController.move(z.centre, 11);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge rang + NDVI
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 8 : 6,
                          vertical: isSelected ? 5 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : NexaTheme.noir.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color, width: isSelected ? 2 : 1.5),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                          ],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            '#${idx + 1}',
                            style: TextStyle(
                              color: isSelected ? NexaTheme.noir : color,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(z.ndviRaw * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: isSelected ? NexaTheme.noir : NexaTheme.blanc,
                              fontSize: isSelected ? 12 : 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ]),
                      ),
                      // Triangle pin
                      CustomPaint(
                        size: const Size(10, 6),
                        painter: _PinPainter(
                          color: isSelected ? color : NexaTheme.noir.withOpacity(0.9),
                          border: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // Position actuelle — point bleu simple
        if (_position != null)
          MarkerLayer(markers: [
            Marker(
              point: _position!,
              width: 20, height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: NexaTheme.blanc, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                      blurRadius: 10, spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ]),
      ],
    );
  }

  // ── TOP BAR ───────────────────────────────────────────

  Widget _buildTopBar() {
    final recommandees = _zones.where((z) => z.qualite.recommandee).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Retour
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: NexaTheme.noir.withOpacity(0.88),
                shape: BoxShape.circle,
                border: Border.all(color: NexaTheme.blanc.withOpacity(0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded, color: NexaTheme.blanc, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          // Info centre
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: NexaTheme.noir.withOpacity(0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NexaTheme.blanc.withOpacity(0.1)),
              ),
              child: Row(children: [
                const Text('🐪', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _zones.isEmpty
                      ? 'Mode Nomade — Analyse NDVI satellite'
                      : recommandees > 0
                          ? '$recommandees zone${recommandees > 1 ? 's' : ''} recommandée${recommandees > 1 ? 's' : ''} · rayon ${_rayonKm.toInt()} km'
                          : 'Aucune zone recommandée · rayon ${_rayonKm.toInt()} km',
                  style: NexaTheme.bodyS.copyWith(
                    color: _zones.isEmpty
                        ? NexaTheme.blanc.withOpacity(0.55)
                        : recommandees > 0 ? NexaTheme.vert : NexaTheme.or,
                    fontSize: 11,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Refresh
          GestureDetector(
            onTap: _rechercher,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: NexaTheme.vert.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: NexaTheme.vert.withOpacity(0.4)),
              ),
              child: const Icon(Icons.refresh_rounded, color: NexaTheme.vert, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  // ── SHEET BAS ─────────────────────────────────────────

  Widget _buildSheet() {
    return Container(
      decoration: BoxDecoration(
        color: NexaTheme.noir,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: NexaTheme.blanc.withOpacity(0.07))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          width: 32, height: 3,
          decoration: BoxDecoration(
            color: NexaTheme.blanc.withOpacity(0.12),
            borderRadius: BorderRadius.circular(2),
          ),
        )),

        // Rayon + profil
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(
              '$_troupeauSize $_espece${_troupeauSize > 1 ? 's' : ''}',
              style: NexaTheme.bodyS.copyWith(
                color: NexaTheme.blanc.withOpacity(0.5), fontSize: 12),
            ),
            const Spacer(),
            Text('${_rayonKm.toInt()} km',
              style: NexaTheme.label.copyWith(color: NexaTheme.vert, fontSize: 12)),
            SizedBox(width: 100, child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: NexaTheme.vert,
                inactiveTrackColor: NexaTheme.blanc.withOpacity(0.1),
                thumbColor: NexaTheme.vert,
                overlayColor: Colors.transparent,
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: _rayonKm,
                min: 20, max: 300,
                onChanged: (v) => setState(() => _rayonKm = v),
                onChangeEnd: (_) => _rechercher(),
              ),
            )),
          ]),
        ),

        const SizedBox(height: 4),

        // Contenu
        if (_selected != null)
          _buildDetail(_selected!)
        else if (_erreur != null)
          _buildErreur()
        else if (_zones.isNotEmpty)
          _buildListe()
        else if (!_isLoading)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Appuyez sur ↺ pour analyser la zone',
              style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.3)),
              textAlign: TextAlign.center),
          ),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }

  // ── LISTE DES ZONES ───────────────────────────────────

  Widget _buildListe() {
    final reco  = _zones.where((z) => z.qualite.recommandee).toList();
    final autre = _zones.where((z) => !z.qualite.recommandee).toList();

    return SizedBox(
      height: 260,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (reco.isNotEmpty) ...[
            _ListHeader(
              titre: 'Recommandées (${reco.length})',
              color: NexaTheme.vert,
            ),
            ...reco.asMap().entries.map((e) =>
              _ZoneTile(
                zone: e.value,
                rang: e.key + 1,
                isTop: e.key == 0,
                onTap: () {
                  setState(() => _selected = e.value);
                  _mapController.move(e.value.centre, 11);
                },
              ).animate().fadeIn(duration: 250.ms, delay: (e.key * 50).ms),
            ),
          ],
          if (autre.isNotEmpty) ...[
            if (reco.isNotEmpty) const SizedBox(height: 6),
            _ListHeader(
              titre: 'Autres zones (${autre.length})',
              color: NexaTheme.blanc.withOpacity(0.3),
            ),
            ...autre.take(3).toList().asMap().entries.map((e) =>
              _ZoneTile(
                zone: e.value,
                rang: reco.length + e.key + 1,
                isTop: false,
                onTap: () {
                  setState(() => _selected = e.value);
                  _mapController.move(e.value.centre, 11);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── DÉTAIL ZONE ───────────────────────────────────────

  Widget _buildDetail(NdviZone z) {
    final color = _hexColor(z.qualite.couleurHex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            // En-tête
            Row(children: [
              Text(z.qualite.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(z.qualite.label,
                  style: NexaTheme.titleL.copyWith(color: color, fontSize: 17)),
                Text(z.label,
                  style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.5))),
              ])),
              // Score NDVI
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${(z.ndviRaw * 100).toStringAsFixed(1)}',
                  style: NexaTheme.displayM.copyWith(color: color, fontSize: 30),
                ),
                Text('NDVI %',
                  style: NexaTheme.label.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.3), fontSize: 9)),
              ]),
            ]),
            const SizedBox(height: 12),
            // Barre NDVI
            _NdviBar(value: z.ndviRaw, color: color),
            const SizedBox(height: 12),
            // Conseil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NexaTheme.blanc.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💡', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(child: Text(z.conseil,
                  style: NexaTheme.bodyS.copyWith(
                    color: NexaTheme.blanc.withOpacity(0.65), fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 10),
            // Métadonnées
            Row(children: [
              _Pill('📍', '${z.distanceKm.toStringAsFixed(0)} km'),
              const SizedBox(width: 6),
              _Pill('🛰️', z.source),
              const SizedBox(width: 6),
              _Pill('📅', '${z.dateImage.day}/${z.dateImage.month}'),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: NexaButton(
            label: 'Fermer',
            onTap: () => setState(() => _selected = null),
            outlined: true,
          )),
          const SizedBox(width: 8),
          Expanded(child: NexaButton(
            label: 'Aller dans cette direction →',
            onTap: () => _naviguer(z),
          )),
        ]),
      ]),
    );
  }

  Widget _buildErreur() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Column(children: [
      Text(_erreur!,
        style: NexaTheme.bodyM.copyWith(color: NexaTheme.blanc.withOpacity(0.4)),
        textAlign: TextAlign.center),
      const SizedBox(height: 12),
      NexaButton(label: 'Réessayer', onTap: _rechercher),
    ]),
  );

  // ── LOADER ────────────────────────────────────────────

  Widget _buildLoader() {
    return Container(
      color: NexaTheme.noir.withOpacity(0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NexaTheme.vert.withOpacity(0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icône satellite animée
            Text('🛰️', style: const TextStyle(fontSize: 40))
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1500.ms, color: NexaTheme.vert),
            const SizedBox(height: 16),
            Text('Analyse satellite',
              style: NexaTheme.titleL.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            Text(_loadingStep,
              style: NexaTheme.bodyS.copyWith(
                color: NexaTheme.blanc.withOpacity(0.45), fontSize: 11),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _loadingProgress / 10.0,
                backgroundColor: NexaTheme.blanc.withOpacity(0.08),
                color: NexaTheme.vert,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            // Sources
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Pill('🛰️', 'NASA MODIS'),
              const SizedBox(width: 8),
              _Pill('🌧️', 'Open-Meteo'),
            ]),
          ]),
        ),
      ),
    );
  }

  void _naviguer(NdviZone z) {
    setState(() => _selected = null);
    _mapController.move(z.centre, 11);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Text(z.qualite.emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '${z.directionLabel} · ${z.distanceKm.toStringAsFixed(0)} km · NDVI ${(z.ndviRaw * 100).toStringAsFixed(1)}%',
        )),
      ]),
      backgroundColor: _hexColor(z.qualite.couleurHex),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS RÉUTILISABLES
// ─────────────────────────────────────────────────────────

class _ZoneTile extends StatelessWidget {
  final NdviZone zone;
  final int rang;
  final bool isTop;
  final VoidCallback onTap;

  const _ZoneTile({
    required this.zone, required this.rang,
    required this.isTop, required this.onTap,
  });

  Color get _color =>
      Color(int.parse(zone.qualite.couleurHex.replaceAll('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _color.withOpacity(isTop ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _color.withOpacity(isTop ? 0.35 : 0.12),
            width: isTop ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Rang
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: isTop ? _color : _color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              isTop ? '★' : '$rang',
              style: TextStyle(
                color: isTop ? NexaTheme.noir : _color,
                fontSize: isTop ? 13 : 10,
                fontWeight: FontWeight.bold,
              ),
            )),
          ),
          const SizedBox(width: 10),
          Text(zone.qualite.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(zone.qualite.label,
              style: NexaTheme.titleL.copyWith(color: _color, fontSize: 13)),
            Text(zone.label,
              style: NexaTheme.bodyS.copyWith(
                color: NexaTheme.blanc.withOpacity(0.4), fontSize: 10)),
          ])),
          // NDVI score
          Text(
            '${(zone.ndviRaw * 100).toStringAsFixed(1)}%',
            style: NexaTheme.titleL.copyWith(color: _color, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: _color.withOpacity(0.4), size: 16),
        ]),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String titre; final Color color;
  const _ListHeader({required this.titre, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(titre, style: NexaTheme.label.copyWith(color: color, fontSize: 10)),
  );
}

class _NdviBar extends StatelessWidget {
  final double value; final Color color;
  const _NdviBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    // Sahel : 0.05 min → 0.45 max → normaliser dans cet intervalle
    final pct = ((value - 0.05) / 0.40).clamp(0.0, 1.0);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Aride', style: NexaTheme.label.copyWith(
          color: NexaTheme.blanc.withOpacity(0.25), fontSize: 9)),
        Text('Végétation dense', style: NexaTheme.label.copyWith(
          color: NexaTheme.blanc.withOpacity(0.25), fontSize: 9)),
      ]),
      const SizedBox(height: 5),
      Stack(children: [
        Container(height: 6, decoration: BoxDecoration(
          color: NexaTheme.blanc.withOpacity(0.07),
          borderRadius: BorderRadius.circular(3),
        )),
        FractionallySizedBox(widthFactor: pct, child: Container(
          height: 6, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFFEF4444), Color(0xFFF97316),
              Color(0xFFEAB308), Color(0xFF84CC16), Color(0xFF22C55E),
            ]),
            borderRadius: BorderRadius.circular(3),
          ),
        )),
        // Curseur
        Positioned(
          left: pct * (MediaQuery.of(context).size.width - 72) - 5,
          child: Container(width: 10, height: 6,
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String icon, label;
  const _Pill(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: NexaTheme.blanc.withOpacity(0.06),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(label, style: NexaTheme.label.copyWith(
        color: NexaTheme.blanc.withOpacity(0.5), fontSize: 9)),
    ]),
  );
}

// ── Triangle pin pour les marqueurs ──────────────────────

class _PinPainter extends CustomPainter {
  final Color color, border;
  const _PinPainter({required this.color, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final fill   = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final path   = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}