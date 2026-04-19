import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../services/zone_service.dart';

enum MapMode { tracage, selection, zones }

class MapScreen extends StatefulWidget {
  final MapScreenArgs? args;
  const MapScreen({super.key, this.args});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(14.716677, -17.467686);
  bool _isLoadingLocation = false;

  List<LatLng> _polygonPoints = [];
  bool _isDrawing = false;
  double _surfaceHa = 0;

  MapMode _mode = MapMode.tracage;
  List<TerrainZone> _zones = [];
  TerrainZone? _selectedZone;
  String? _highlightZoneId;
  String? _zoneActiveId; // Zone choisie par l'éleveur

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null) {
      if (args.zones != null && args.zones!.isNotEmpty) {
        _zones = args.zones!;
        _mode = MapMode.zones;
        _highlightZoneId = args.highlightZoneId;
        if (args.highlightZoneId != null) {
          _selectedZone = _zones.firstWhere(
            (z) => z.id == args.highlightZoneId,
            orElse: () => _zones.first,
          );
        }
      }
      if (args.polygonPoints != null) _polygonPoints = args.polygonPoints!;
      if (args.surfaceHa != null) _surfaceHa = args.surfaceHa!;
    }
    _locateUser();
  }

  Future<void> _locateUser() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() { _center = LatLng(pos.latitude, pos.longitude); _isLoadingLocation = false; });
      if (_zones.isNotEmpty && _polygonPoints.isNotEmpty) {
        final c = _highlightZoneId != null
            ? _zones.firstWhere((z) => z.id == _highlightZoneId, orElse: () => _zones.first).centre
            : _centrePolygon(_polygonPoints);
        _mapController.move(c, 14);
      } else {
        _mapController.move(_center, 14);
      }
    } catch (_) { setState(() => _isLoadingLocation = false); }
  }

  void _addPoint(LatLng point) {
    if (!_isDrawing || _mode != MapMode.tracage) return;
    setState(() {
      _polygonPoints.add(point);
      if (_polygonPoints.length >= 3) _surfaceHa = _calculateSurface(_polygonPoints);
    });
  }

  void _undoLastPoint() {
    if (_polygonPoints.isNotEmpty && _mode == MapMode.tracage) {
      setState(() {
        _polygonPoints.removeLast();
        _surfaceHa = _polygonPoints.length >= 3 ? _calculateSurface(_polygonPoints) : 0;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _polygonPoints.clear(); _surfaceHa = 0;
      _zones = []; _selectedZone = null;
      _highlightZoneId = null; _zoneActiveId = null;
      _mode = MapMode.tracage;
    });
  }

  // ── GÉNÉRER LES 4 ZONES PUIS PASSER EN MODE SÉLECTION ────
  void _genererZones() {
    if (_surfaceHa <= 0 || _polygonPoints.length < 3) return;
    final zones = ZoneService.diviserTerrain(
      polygonTotal: _polygonPoints,
      surfaceHaTotal: _surfaceHa,
    );
    setState(() { _zones = zones; _mode = MapMode.selection; _isDrawing = false; });
  }

  // ── L'ÉLEVEUR CHOISIT SA ZONE ACTIVE ─────────────────────
  // ✅ Fix Bug 1 — peut être rappelé pour changer la sélection
  void _choisirZoneActive(String zoneId) {
    setState(() {
      _zoneActiveId = zoneId;
      // Recalculer les zones avec la nouvelle zone active
      _zones = ZoneService.diviserTerrain(
        polygonTotal: _polygonPoints,
        surfaceHaTotal: _surfaceHa,
        zoneActiveId: zoneId,
      );
      // Rester en mode selection pour permettre de changer d'avis
      // Passer en mode zones seulement après confirmation
    });
  }

  // Confirmer la sélection et passer en mode zones
  void _confirmerSelection() {
    if (_zoneActiveId == null) return;
    setState(() => _mode = MapMode.zones);
  }

  // ── CONFIRMER ET RETOURNER LA SURFACE ────────────────────
  void _confirmerZonePourAnalyse() {
    if (_surfaceHa <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('Zone ${_zoneActiveId ?? ""} · ${_surfaceHa.toStringAsFixed(2)} ha confirmée ✅'),
      ]),
      backgroundColor: NexaTheme.vert,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) context.pop(_surfaceHa);
    });
  }

  double _calculateSurface(List<LatLng> points) {
    if (points.length < 3) return 0;
    const R = 6371000.0;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += (points[j].longitudeInRad - points[i].longitudeInRad) *
          (2 + points[i].latitudeInRad.abs() + points[j].latitudeInRad.abs());
    }
    return (area.abs() * R * R / 2 / 10000).abs();
  }

  LatLng _centrePolygon(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in points) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / points.length, lng / points.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexaTheme.noir,
      body: Stack(children: [

        // ── CARTE ───────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center, initialZoom: 13,
            onTap: (_, point) {
              if (_mode == MapMode.tracage && _isDrawing) _addPoint(point);
              else if (_mode == MapMode.zones) setState(() => _selectedZone = null);
            },
            interactionOptions: InteractionOptions(
              flags: _isDrawing ? InteractiveFlag.none : InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.nexa.app',
            ),

            // MODE TRACAGE
            if (_mode == MapMode.tracage) ...[
              if (_polygonPoints.length >= 3)
                PolygonLayer(polygons: [Polygon(
                  points: _polygonPoints,
                  color: NexaTheme.vert.withOpacity(0.2),
                  borderColor: NexaTheme.vert, borderStrokeWidth: 2.5,
                )]),
              if (_polygonPoints.length >= 2)
                PolylineLayer(polylines: [Polyline(
                  points: [..._polygonPoints, if (_polygonPoints.isNotEmpty) _polygonPoints.first],
                  color: NexaTheme.vert.withOpacity(0.7), strokeWidth: 2,
                )]),
              CircleLayer(circles: _polygonPoints.asMap().entries.map((e) => CircleMarker(
                point: e.value, radius: e.key == 0 ? 7 : 5,
                color: e.key == 0 ? NexaTheme.or : NexaTheme.vert,
                borderColor: NexaTheme.blanc, borderStrokeWidth: 1.5, useRadiusInMeter: false,
              )).toList()),
            ],

            // MODE SÉLECTION — zones grises en attente de choix
            if (_mode == MapMode.selection || _mode == MapMode.zones) ...[
              if (_polygonPoints.length >= 3)
                PolylineLayer(polylines: [Polyline(
                  points: [..._polygonPoints, _polygonPoints.first],
                  color: NexaTheme.blanc.withOpacity(0.3), strokeWidth: 1.5,
                )]),

              if (_zones.any((z) => z.polygon.length >= 3))
                PolygonLayer(
                  polygons: _zones.where((z) => z.polygon.length >= 3).map((z) {
                    final isHighlighted = _highlightZoneId == z.id || _selectedZone?.id == z.id;
                    final isChoisie = z.id == _zoneActiveId;
                    return Polygon(
                      points: z.polygon,
                      color: isChoisie
                          ? NexaTheme.vert.withOpacity(0.45)
                          : z.couleur.withOpacity(isHighlighted ? 0.4 : 0.2),
                      borderColor: isChoisie
                          ? NexaTheme.vert
                          : z.couleur.withOpacity(isHighlighted ? 1.0 : 0.6),
                      borderStrokeWidth: isChoisie || isHighlighted ? 3 : 1.5,
                    );
                  }).toList(),
                ),

              MarkerLayer(
                markers: _zones.map((z) {
                  final isHighlighted = _highlightZoneId == z.id;
                  final isChoisie = z.id == _zoneActiveId;
                  final point = z.polygon.length >= 3 ? z.centre : _center;
                  return Marker(
                    point: point, width: 90,
                    height: isHighlighted || isChoisie ? 72 : 60,
                    child: GestureDetector(
                      onTap: () {
                        if (_mode == MapMode.selection) {
                          _choisirZoneActive(z.id);
                        } else {
                          setState(() => _selectedZone = _selectedZone?.id == z.id ? null : z);
                        }
                      },
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (isChoisie)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(color: NexaTheme.vert, borderRadius: BorderRadius.circular(6)),
                            child: Text('📍 Active', style: NexaTheme.label.copyWith(color: NexaTheme.noir, fontSize: 8)),
                          ),
                        if (isHighlighted && !isChoisie)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(color: z.couleur, borderRadius: BorderRadius.circular(6)),
                            child: Text('📍 Ici', style: NexaTheme.label.copyWith(color: NexaTheme.noir, fontSize: 8)),
                          ),
                        Text(isChoisie ? '🟢' : z.emoji, style: TextStyle(fontSize: isChoisie ? 22 : 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NexaTheme.noir.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isChoisie ? NexaTheme.vert : z.couleur.withOpacity(0.6), width: isChoisie ? 1.5 : 1),
                          ),
                          child: Text(z.nom, style: NexaTheme.label.copyWith(color: isChoisie ? NexaTheme.vert : z.couleur, fontSize: 9)),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],

            if (!_isLoadingLocation)
              MarkerLayer(markers: [Marker(
                point: _center, width: 20, height: 20,
                child: Container(decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6), shape: BoxShape.circle,
                  border: Border.all(color: NexaTheme.blanc, width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4), blurRadius: 8)],
                )),
              )]),
          ],
        ),

        // ── HEADER ──────────────────────────────────────────
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                if (_mode == MapMode.zones && _highlightZoneId == null) {
                  setState(() { _mode = MapMode.tracage; _zones = []; _selectedZone = null; _zoneActiveId = null; });
                } else if (_mode == MapMode.selection) {
                  setState(() { _mode = MapMode.tracage; _zones = []; });
                } else {
                  context.pop();
                }
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: NexaTheme.noir.withOpacity(0.85), shape: BoxShape.circle,
                  border: Border.all(color: NexaTheme.blanc.withOpacity(0.1)),
                ),
                child: Icon(
                  _mode == MapMode.zones && _highlightZoneId == null ? Icons.edit_outlined : Icons.arrow_back_ios_rounded,
                  color: NexaTheme.blanc, size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: NexaTheme.noir.withOpacity(0.85), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NexaTheme.blanc.withOpacity(0.1)),
              ),
              child: Text(
                _mode == MapMode.selection
                    ? '👆 Touchez la zone que vous allez analyser en premier'
                    : _mode == MapMode.zones
                        ? _highlightZoneId != null
                            ? '📍 Zone ${_highlightZoneId!} mise en évidence'
                            : '📐 ${_surfaceHa.toStringAsFixed(2)} ha · ${ZoneService.resumeZones(_zones)}'
                        : _surfaceHa > 0
                            ? '📐 ${_surfaceHa.toStringAsFixed(2)} ha · ${_polygonPoints.length} points'
                            : _isDrawing ? 'Tracez les limites de votre terrain' : 'Activez le dessin pour tracer',
                style: NexaTheme.bodyS.copyWith(
                  color: _mode == MapMode.selection
                      ? NexaTheme.or
                      : _surfaceHa > 0 ? NexaTheme.vert : NexaTheme.blanc.withOpacity(0.6),
                  fontSize: 11,
                ),
                maxLines: 2,
              ),
            )),
          ]),
        )),

        // ── OUTILS (tracage) ─────────────────────────────────
        if (_mode == MapMode.tracage)
          Positioned(
            right: 16, top: MediaQuery.of(context).padding.top + 72,
            child: Column(children: [
              _ToolBtn(icon: _isDrawing ? Icons.pan_tool : Icons.edit_outlined,
                color: _isDrawing ? NexaTheme.vert : null,
                onTap: () => setState(() => _isDrawing = !_isDrawing)),
              const SizedBox(height: 8),
              _ToolBtn(icon: Icons.undo_rounded,
                onTap: _undoLastPoint, enabled: _polygonPoints.isNotEmpty),
              const SizedBox(height: 8),
              _ToolBtn(icon: Icons.delete_outline_rounded,
                color: NexaTheme.rouge.withOpacity(0.7),
                onTap: _clearAll, enabled: _polygonPoints.isNotEmpty),
              const SizedBox(height: 8),
              _ToolBtn(icon: Icons.my_location_rounded, onTap: _locateUser),
            ]).animate().fadeIn(duration: 400.ms).slideX(begin: 0.3),
          ),

        // ── DÉTAIL ZONE SÉLECTIONNÉE ─────────────────────────
        if (_mode == MapMode.zones && _selectedZone != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72, left: 16, right: 72,
            child: _ZoneDetailCard(
              zone: _selectedZone!,
              onClose: () => setState(() => _selectedZone = null),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),
          ),

        // ── BOTTOM PANEL ─────────────────────────────────────
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16, left: 16, right: 16,
          child: _buildBottomPanel(),
        ),
      ]),
    );
  }

  Widget _buildBottomPanel() {
    switch (_mode) {
      case MapMode.tracage:
        if (_surfaceHa <= 0) return const SizedBox.shrink();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: NexaTheme.noir.withOpacity(0.9), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NexaTheme.vert.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.square_foot, color: NexaTheme.vert, size: 16),
              const SizedBox(width: 8),
              Text('${_surfaceHa.toStringAsFixed(2)} ha · ${_polygonPoints.length} points',
                style: NexaTheme.titleM.copyWith(color: NexaTheme.vert)),
            ]),
          ),
          NexaButton(label: 'Diviser en 4 zones →', onTap: _genererZones),
        ]).animate().fadeIn().slideY(begin: 0.3);

      case MapMode.selection:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NexaTheme.noir.withOpacity(0.95), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _zoneActiveId != null
                ? NexaTheme.vert.withOpacity(0.4)
                : NexaTheme.or.withOpacity(0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_zoneActiveId != null ? '✅' : '👆', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _zoneActiveId != null
                      ? 'Zone $_zoneActiveId sélectionnée'
                      : 'Choisissez votre première zone',
                  style: NexaTheme.titleL.copyWith(
                    fontSize: 15,
                    color: _zoneActiveId != null ? NexaTheme.vert : NexaTheme.blanc,
                  ),
                ),
                Text(
                  _zoneActiveId != null
                      ? 'Vous pouvez changer · Touchez une autre zone'
                      : 'Touchez la zone que vous allez analyser en premier',
                  style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.45), fontSize: 11),
                ),
              ])),
            ]),
            const SizedBox(height: 12),
            // 4 boutons de sélection
            Row(children: _zones.map((z) {
              final isChoisie = z.id == _zoneActiveId;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => _choisirZoneActive(z.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isChoisie ? NexaTheme.vert.withOpacity(0.2) : NexaTheme.blanc.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isChoisie ? NexaTheme.vert : NexaTheme.blanc.withOpacity(0.15),
                        width: isChoisie ? 1.5 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Text(isChoisie ? '🟢' : '⚪', style: const TextStyle(fontSize: 16)),
                      Text(z.id, style: NexaTheme.label.copyWith(
                        color: isChoisie ? NexaTheme.vert : NexaTheme.blanc, fontSize: 11)),
                    ]),
                  ),
                ),
              ));
            }).toList()),
            // Bouton confirmer — visible seulement si une zone est choisie
            if (_zoneActiveId != null) ...[
              const SizedBox(height: 10),
              NexaButton(
                label: 'Confirmer Zone $_zoneActiveId →',
                onTap: _confirmerSelection,
              ),
            ],
          ]),
        ).animate().fadeIn().slideY(begin: 0.3);

      case MapMode.zones:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NexaTheme.noir.withOpacity(0.95), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NexaTheme.vert.withOpacity(0.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: _zones.map((z) {
              final isActive = z.id == _zoneActiveId;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: z.couleur.withOpacity(isActive ? 0.2 : 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: z.couleur.withOpacity(isActive ? 0.8 : 0.2), width: isActive ? 1.5 : 1),
                  ),
                  child: Column(children: [
                    Text(isActive ? '🟢' : z.emoji, style: const TextStyle(fontSize: 14)),
                    Text(z.id, style: NexaTheme.label.copyWith(color: z.couleur, fontSize: 10)),
                    Text(isActive ? 'Active' : z.status.label.substring(0, z.status.label.length.clamp(0, 5)),
                      style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.4), fontSize: 8)),
                  ]),
                ),
              ));
            }).toList()),
            const SizedBox(height: 10),
            if (_highlightZoneId == null)
              Row(children: [
                Expanded(child: NexaButton(
                  label: 'Plan →',
                  onTap: () => context.push('/rotation', extra: _zones),
                  outlined: true,
                )),
                const SizedBox(width: 8),
                Expanded(child: NexaButton(
                  label: 'Analyser →',
                  onTap: _confirmerZonePourAnalyse,
                )),
              ])
            else
              NexaButton(label: '← Retour au plan', onTap: () => context.pop()),
          ]),
        ).animate().fadeIn().slideY(begin: 0.3);
    }
  }
}

// ── ZONE DETAIL CARD ──────────────────────────────────────

class _ZoneDetailCard extends StatelessWidget {
  final TerrainZone zone;
  final VoidCallback onClose;
  const _ZoneDetailCard({required this.zone, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexaTheme.noir.withOpacity(0.95), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zone.couleur.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: zone.couleur.withOpacity(0.2), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(zone.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(zone.nom, style: NexaTheme.titleL.copyWith(color: zone.couleur, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: zone.couleur.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(zone.status.label, style: NexaTheme.label.copyWith(color: zone.couleur, fontSize: 8)),
            ),
          ])),
          GestureDetector(onTap: onClose, child: Icon(Icons.close, color: NexaTheme.blanc.withOpacity(0.4), size: 18)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _Chip('📐', '${zone.surfaceHa.toStringAsFixed(1)} ha'),
          if (zone.joursDisponibles > 0) ...[const SizedBox(width: 6), _Chip('📅', '${zone.joursRestants}j rest.')],
        ]),
        const SizedBox(height: 6),
        Text(zone.status.description, style: NexaTheme.bodyS.copyWith(color: NexaTheme.blanc.withOpacity(0.6), fontSize: 11)),
        if (zone.derniereAnalyse != null) ...[
          const SizedBox(height: 4),
          Text('Analyse : ${zone.derniereAnalyse!.scoreSante.toInt()}/100 · ${zone.derniereAnalyse!.gdmG.toStringAsFixed(1)} g/m²',
            style: NexaTheme.label.copyWith(color: NexaTheme.blanc.withOpacity(0.3), fontSize: 9)),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String icon, label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: NexaTheme.blanc.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(label, style: NexaTheme.label.copyWith(fontSize: 9)),
    ]),
  );
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final bool enabled;
  const _ToolBtn({required this.icon, required this.onTap, this.color, this.enabled = true});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: NexaTheme.noir.withOpacity(0.85), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? NexaTheme.blanc.withOpacity(enabled ? 0.15 : 0.05)),
      ),
      child: Icon(icon, color: enabled ? (color ?? NexaTheme.blanc.withOpacity(0.8)) : NexaTheme.blanc.withOpacity(0.2), size: 20),
    ),
  );
}