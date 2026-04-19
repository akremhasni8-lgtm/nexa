import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// EXTENSIONS SUR MODÈLES (UI)
// ─────────────────────────────────────────────────────────

extension ZoneStatusUI on ZoneStatus {
  String get label {
    switch (this) {
      case ZoneStatus.active:     return 'ACTIVE';
      case ZoneStatus.attente:    return 'EN ATTENTE';
      case ZoneStatus.repos:      return 'REPOS';
      case ZoneStatus.prete:      return 'PRÊTE';
      case ZoneStatus.finDeCycle: return 'FIN CYCLE';
      case ZoneStatus.epuisee:    return 'ÉPUISÉE';
    }
  }

  String get emoji {
    switch (this) {
      case ZoneStatus.active:     return '🟢';
      case ZoneStatus.attente:    return '⚪';
      case ZoneStatus.repos:      return '🔵';
      case ZoneStatus.prete:      return '🟡';
      case ZoneStatus.finDeCycle: return '🟠';
      case ZoneStatus.epuisee:    return '🔴';
    }
  }

  Color get couleur {
    switch (this) {
      case ZoneStatus.active:     return NexaTheme.vert;
      case ZoneStatus.attente:    return NexaTheme.gris;
      case ZoneStatus.repos:      return const Color(0xFF3B82F6);
      case ZoneStatus.prete:      return NexaTheme.or;
      case ZoneStatus.finDeCycle: return const Color(0xFFF97316);
      case ZoneStatus.epuisee:    return NexaTheme.rouge;
    }
  }

  String get description {
    switch (this) {
      case ZoneStatus.active:     return 'Zone en cours de pâturage';
      case ZoneStatus.attente:    return 'Pas encore analysée';
      case ZoneStatus.repos:      return 'En régénération — ne pas pâturer';
      case ZoneStatus.prete:      return 'Disponible pour la prochaine rotation';
      case ZoneStatus.finDeCycle: return 'Préparez le déplacement maintenant';
      case ZoneStatus.epuisee:    return 'Quittez immédiatement cette zone';
    }
  }

  String get actionLabel {
    switch (this) {
      case ZoneStatus.active:     return 'Pâturage en cours';
      case ZoneStatus.attente:    return 'Analyser cette zone';
      case ZoneStatus.repos:      return 'Repos — ne pas utiliser';
      case ZoneStatus.prete:      return 'Disponible maintenant';
      case ZoneStatus.finDeCycle: return 'Déplacer le troupeau bientôt';
      case ZoneStatus.epuisee:    return 'Partir immédiatement';
    }
  }
}

extension SavedZoneLogic on SavedZone {
  LatLng get centre {
    if (polygonLats.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (int i = 0; i < polygonLats.length; i++) {
      lat += polygonLats[i];
      lng += polygonLngs[i];
    }
    return LatLng(lat / polygonLats.length, lng / polygonLats.length);
  }

  List<LatLng> get polygon => List.generate(
    polygonLats.length,
    (i) => LatLng(polygonLats[i], polygonLngs[i]),
  );

  Color get couleur => status.couleur;
  String get emoji  => status.emoji;

  int get joursRestants {
    if (dateDebutPaturage == null || joursDisponibles <= 0) return joursDisponibles;
    final passes = DateTime.now().difference(dateDebutPaturage!).inDays;
    return (joursDisponibles - passes).clamp(0, joursDisponibles);
  }
}

// ─────────────────────────────────────────────────────────
// ALIAS POUR COMPATIBILITÉ (TRANSITION PROGRESSIVE)
// ─────────────────────────────────────────────────────────
typedef TerrainZone = SavedZone;

// ─────────────────────────────────────────────────────────
// SERVICE PRINCIPAL
// ─────────────────────────────────────────────────────────

class ZoneService {

  // ── DIVISION DU TERRAIN EN 4 ZONES ───────────────────────

  static List<SavedZone> diviserTerrain({
    required List<LatLng> polygonTotal,
    required double surfaceHaTotal,
    String? zoneActiveId,
  }) {
    if (polygonTotal.length < 3) return [];

    final centre = _centroide(polygonTotal);
    final midLat = centre.latitude;
    final midLng = centre.longitude;
    final bbox   = _bbox(polygonTotal);
    final surfaceParZone = surfaceHaTotal / 4;

    final polyA = _clipPolygon(polygonTotal, latMin: midLat, latMax: bbox['maxLat']!, lngMin: bbox['minLng']!, lngMax: midLng);
    final polyB = _clipPolygon(polygonTotal, latMin: midLat, latMax: bbox['maxLat']!, lngMin: midLng, lngMax: bbox['maxLng']!);
    final polyC = _clipPolygon(polygonTotal, latMin: bbox['minLat']!, latMax: midLat, lngMin: midLng, lngMax: bbox['maxLng']!);
    final polyD = _clipPolygon(polygonTotal, latMin: bbox['minLat']!, latMax: midLat, lngMin: bbox['minLng']!, lngMax: midLng);

    final ids = ['A', 'B', 'C', 'D'];
    final polys = [
      polyA.isNotEmpty ? polyA : _quadrantFallback(polygonTotal, 'A', midLat, midLng, bbox),
      polyB.isNotEmpty ? polyB : _quadrantFallback(polygonTotal, 'B', midLat, midLng, bbox),
      polyC.isNotEmpty ? polyC : _quadrantFallback(polygonTotal, 'C', midLat, midLng, bbox),
      polyD.isNotEmpty ? polyD : _quadrantFallback(polygonTotal, 'D', midLat, midLng, bbox),
    ];

    return List.generate(4, (i) {
      final id = ids[i];
      final isActive = zoneActiveId == id;
      final currentPoly = polys[i];

      return SavedZone(
        id: id,
        name: 'Zone $id',
        latitude: _centroide(currentPoly).latitude,
        longitude: _centroide(currentPoly).longitude,
        polygonLats: currentPoly.map((p) => p.latitude).toList(),
        polygonLngs: currentPoly.map((p) => p.longitude).toList(),
        surfaceHa: surfaceParZone,
        status: zoneActiveId != null
            ? (isActive ? ZoneStatus.active : ZoneStatus.attente)
            : ZoneStatus.attente,
        isNext: false,
        dateDebutPaturage: isActive ? DateTime.now() : null,
      );
    });
  }

  // ── TRANSITION VERS LA ZONE SUIVANTE ─────────────────────

  static List<SavedZone> effectuerTransition(
    List<SavedZone> zones,
    String fromId,
    String toId,
  ) {
    return zones.map((z) {
      if (z.id == fromId) {
        final joursRegen = z.joursDisponibles > 0
            ? (z.joursDisponibles * 0.75).ceil().clamp(21, 90)
            : 30;
        return z.copyWith(
          status: ZoneStatus.repos,
          isNext: false,
          joursDisponibles: joursRegen,
        );
      } else if (z.id == toId) {
        return z.copyWith(
          status: ZoneStatus.active,
          isNext: false,
          joursDisponibles: 0,
          dateDebutPaturage: DateTime.now(),
        );
      }
      return z.copyWith(isNext: false);
    }).toList();
  }

  // ── METTRE À JOUR LE STATUT D'UNE ZONE APRÈS ANALYSE ─────

  static List<SavedZone> mettreAJourApresAnalyse(
    List<SavedZone> zones,
    String zoneId,
    AnalysisResult result,
  ) {
    return zones.map((z) {
      if (z.id != zoneId) return z;

      ZoneStatus newStatus;
      switch (result.statut) {
        case PastureStatus.excellent:
        case PastureStatus.bon:
          newStatus = ZoneStatus.active;
          break;
        case PastureStatus.attention:
          newStatus = ZoneStatus.finDeCycle;
          break;
        case PastureStatus.critique:
          newStatus = ZoneStatus.epuisee;
          break;
      }

      return z.copyWith(
        status: newStatus,
        derniereAnalyse: result,
        joursDisponibles: result.joursDisponibles,
        dateDebutPaturage: DateTime.now(),
        lastAnalyzed: result.timestamp,
        lastScore: result.scoreSante,
      );
    }).toList();
  }

  // ── CALCULER LA PROCHAINE ZONE ────────────────────────────

  static SavedZone? prochaineZone(List<SavedZone> zones, String activeId) {
    final ordre = ['A', 'B', 'C', 'D'];
    final activeIndex = ordre.indexOf(activeId);
    if (activeIndex == -1) return null;

    for (int i = 1; i <= 4; i++) {
      final nextId = ordre[(activeIndex + i) % 4];
      final zone = zones.firstWhere((z) => z.id == nextId, orElse: () => zones.first);
      if (zone.status != ZoneStatus.active && zone.status != ZoneStatus.epuisee) {
        return zone;
      }
    }
    return null;
  }

  // ── PERSISTANCE HIVE ──────────────────────────────────────

  static Future<void> sauvegarderZones(List<SavedZone> zones) async {
    final box = Hive.box<SavedZone>('zones');
    await box.clear();
    for (var z in zones) {
      await box.put(z.id, z);
    }
  }

  static List<SavedZone>? chargerZones() {
    final box = Hive.box<SavedZone>('zones');
    if (box.isEmpty) return null;
    return box.values.toList();
  }

  static Future<void> effacerZones() async {
    final box = Hive.box<SavedZone>('zones');
    await box.clear();
  }

  // ── RÉSUMÉ ────────────────────────────────────────────────

  static String resumeZones(List<SavedZone> zones) {
    final active   = zones.where((z) => z.status == ZoneStatus.active).length;
    final repos    = zones.where((z) => z.status == ZoneStatus.repos).length;
    final pretes   = zones.where((z) => z.status == ZoneStatus.prete || z.status == ZoneStatus.attente).length;
    final epuisees = zones.where((z) => z.status == ZoneStatus.epuisee).length;
    return '$active active · $repos repos · $pretes dispo · $epuisees épuisées';
  }

  // ── ALGORITHME SUTHERLAND-HODGMAN ─────────────────────────

  static List<LatLng> _clipPolygon(
    List<LatLng> polygon, {
    required double latMin, required double latMax,
    required double lngMin, required double lngMax,
  }) {
    List<LatLng> out = List.from(polygon);

    out = _clipEdge(out, (p) => p.latitude >= latMin, (a, b) {
      final t = (latMin - a.latitude) / (b.latitude - a.latitude);
      return LatLng(latMin, a.longitude + t * (b.longitude - a.longitude));
    });
    out = _clipEdge(out, (p) => p.latitude <= latMax, (a, b) {
      final t = (latMax - a.latitude) / (b.latitude - a.latitude);
      return LatLng(latMax, a.longitude + t * (b.longitude - a.longitude));
    });
    out = _clipEdge(out, (p) => p.longitude >= lngMin, (a, b) {
      final t = (lngMin - a.longitude) / (b.longitude - a.longitude);
      return LatLng(a.latitude + t * (b.latitude - a.latitude), lngMin);
    });
    out = _clipEdge(out, (p) => p.longitude <= lngMax, (a, b) {
      final t = (lngMax - a.longitude) / (b.longitude - a.longitude);
      return LatLng(a.latitude + t * (b.latitude - a.latitude), lngMax);
    });
    return out;
  }

  static List<LatLng> _clipEdge(
    List<LatLng> poly,
    bool Function(LatLng) inside,
    LatLng Function(LatLng, LatLng) intersect,
  ) {
    if (poly.isEmpty) return [];
    final out = <LatLng>[];
    for (int i = 0; i < poly.length; i++) {
      final cur  = poly[i];
      final prev = poly[(i - 1 + poly.length) % poly.length];
      if (inside(cur)) {
        if (!inside(prev)) out.add(intersect(prev, cur));
        out.add(cur);
      } else if (inside(prev)) {
        out.add(intersect(prev, cur));
      }
    }
    return out;
  }

  static List<LatLng> _quadrantFallback(
    List<LatLng> polygon, String id, double midLat, double midLng,
    Map<String, double> bbox,
  ) {
    switch (id) {
      case 'A': return [LatLng(bbox['maxLat']!, bbox['minLng']!), LatLng(bbox['maxLat']!, midLng), LatLng(midLat, midLng), LatLng(midLat, bbox['minLng']!)];
      case 'B': return [LatLng(bbox['maxLat']!, midLng), LatLng(bbox['maxLat']!, bbox['maxLng']!), LatLng(midLat, bbox['maxLng']!), LatLng(midLat, midLng)];
      case 'C': return [LatLng(midLat, midLng), LatLng(midLat, bbox['maxLng']!), LatLng(bbox['minLat']!, bbox['maxLng']!), LatLng(bbox['minLat']!, midLng)];
      default:  return [LatLng(midLat, bbox['minLng']!), LatLng(midLat, midLng), LatLng(bbox['minLat']!, midLng), LatLng(bbox['minLat']!, bbox['minLng']!)];
    }
  }

  static LatLng _centroide(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in points) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / points.length, lng / points.length);
  }

  static Map<String, double> _bbox(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat)  minLat = p.latitude;
      if (p.latitude > maxLat)  maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return {'minLat': minLat, 'maxLat': maxLat, 'minLng': minLng, 'maxLng': maxLng};
  }
}

// ─────────────────────────────────────────────────────────
// ARGS NAVIGATION CARTE
// ─────────────────────────────────────────────────────────

class MapScreenArgs {
  final List<SavedZone>? zones;
  final List<LatLng>? polygonPoints;
  final double? surfaceHa;
  final String? highlightZoneId;

  const MapScreenArgs({
    this.zones,
    this.polygonPoints,
    this.surfaceHa,
    this.highlightZoneId,
  });
}

// ─────────────────────────────────────────────────────────
// ARGS NAVIGATION CAMÉRA
// ─────────────────────────────────────────────────────────

class CameraArgs {
  final List<SavedZone> zones;
  final String zoneAnalyseeId;

  const CameraArgs({
    required this.zones,
    required this.zoneAnalyseeId,
  });
}
