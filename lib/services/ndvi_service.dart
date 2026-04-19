import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────
// MODÈLES
// ─────────────────────────────────────────────────────────

class NdviZone {
  final LatLng centre;
  final double ndviRaw;       // valeur NDVI réelle -1 à 1
  final double distanceKm;
  final String directionLabel;
  final NdviQualite qualite;
  final DateTime dateImage;
  final String source;        // 'MODIS' ou 'OpenMeteo'

  const NdviZone({
    required this.centre,
    required this.ndviRaw,
    required this.distanceKm,
    required this.directionLabel,
    required this.qualite,
    required this.dateImage,
    required this.source,
  });

  String get label => '$directionLabel · ${distanceKm.toStringAsFixed(0)} km';
  String get conseil => qualite.conseil;
  String get ndviDisplay => '${(ndviRaw * 100).toStringAsFixed(1)}%';
}

// ─────────────────────────────────────────────────────────
// SEUILS NDVI ADAPTÉS AU SAHEL
// Sahel naturel : 0.05 (saison sèche) → 0.45 (saison pluies)
// On adapte les seuils à cette réalité
// ─────────────────────────────────────────────────────────

enum NdviQualite { excellente, bonne, moyenne, faible, nulle }

extension NdviQualiteExt on NdviQualite {
  String get label {
    switch (this) {
      case NdviQualite.excellente: return 'Excellente';
      case NdviQualite.bonne:      return 'Bonne';
      case NdviQualite.moyenne:    return 'Correcte';
      case NdviQualite.faible:     return 'Faible';
      case NdviQualite.nulle:      return 'Très faible';
    }
  }

  String get emoji {
    switch (this) {
      case NdviQualite.excellente: return '🟢';
      case NdviQualite.bonne:      return '🟡';
      case NdviQualite.moyenne:    return '🟠';
      case NdviQualite.faible:     return '🔴';
      case NdviQualite.nulle:      return '⚫';
    }
  }

  String get couleurHex {
    switch (this) {
      case NdviQualite.excellente: return '#22C55E';
      case NdviQualite.bonne:      return '#84CC16';
      case NdviQualite.moyenne:    return '#EAB308';
      case NdviQualite.faible:     return '#F97316';
      case NdviQualite.nulle:      return '#EF4444';
    }
  }

  String get conseil {
    switch (this) {
      case NdviQualite.excellente:
        return 'Végétation dense et riche. Zone idéale — recommandée en priorité pour le troupeau.';
      case NdviQualite.bonne:
        return 'Bonne végétation. Zone suffisante pour nourrir le troupeau correctement.';
      case NdviQualite.moyenne:
        return 'Végétation modérée. Acceptable mais surveillez la consommation quotidienne.';
      case NdviQualite.faible:
        return 'Végétation limitée. À utiliser seulement si aucune meilleure zone n\'est accessible.';
      case NdviQualite.nulle:
        return 'Zone aride. Quasi aucune végétation disponible pour le troupeau.';
    }
  }

  bool get recommandee =>
      this == NdviQualite.excellente || this == NdviQualite.bonne;

  // Seuils adaptés au Sahel (NDVI réel -1 à 1)
  static NdviQualite fromNdvi(double ndvi) {
    // Sahel : saison pluies 0.3-0.45 = excellente
    //         saison sèche  0.1-0.2  = correcte
    if (ndvi >= 0.30) return NdviQualite.excellente;
    if (ndvi >= 0.20) return NdviQualite.bonne;
    if (ndvi >= 0.12) return NdviQualite.moyenne;
    if (ndvi >= 0.05) return NdviQualite.faible;
    return NdviQualite.nulle;
  }
}

// ─────────────────────────────────────────────────────────
// SERVICE NDVI
// ─────────────────────────────────────────────────────────

class NdviService {

  // ── URL TILES NASA GIBS pour affichage carte ─────────────
  static String gibsTileUrl() {
    final d = DateTime.now().subtract(const Duration(days: 10));
    final date = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    return 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/'
        'MODIS_Terra_NDVI_8Day/default/$date/GoogleMapsCompatible/{z}/{y}/{x}.png';
  }

  // ── RECHERCHE PRINCIPALE ──────────────────────────────────
  static Future<List<NdviZone>> rechercherAvecFallback({
    required LatLng position,
    required double rayonKm,
    int nombrePoints = 10,
  }) async {
    // 1. Générer les candidats sur terre uniquement
    final candidats = await _genererPointsTerre(position, rayonKm, nombrePoints);
    if (candidats.isEmpty) return [];

    final zones = <NdviZone>[];

    // 2. Traiter chaque point séquentiellement pour éviter rate limiting
    for (final point in candidats) {
      // Essayer MODIS d'abord
      final resultatModis = await _fetchModis(point);

      if (resultatModis != null) {
        zones.add(NdviZone(
          centre: point,
          ndviRaw: resultatModis,
          distanceKm: _distanceKm(position, point),
          directionLabel: _direction(position, point),
          qualite: NdviQualiteExt.fromNdvi(resultatModis),
          dateImage: DateTime.now().subtract(const Duration(days: 8)),
          source: 'MODIS',
        ));
        continue;
      }

      // Fallback Open-Meteo si MODIS indisponible
      final resultatMeteo = await _fetchOpenMeteoNdvi(point);
      if (resultatMeteo != null) {
        zones.add(NdviZone(
          centre: point,
          ndviRaw: resultatMeteo,
          distanceKm: _distanceKm(position, point),
          directionLabel: _direction(position, point),
          qualite: NdviQualiteExt.fromNdvi(resultatMeteo),
          dateImage: DateTime.now().subtract(const Duration(days: 1)),
          source: 'Météo',
        ));
      }
    }

    // 3. Trier par NDVI décroissant
    zones.sort((a, b) => b.ndviRaw.compareTo(a.ndviRaw));
    return zones;
  }

  // ── GÉNÉRER DES POINTS SUR TERRE UNIQUEMENT ───────────────
  // Utilise Nominatim pour vérifier si le point est sur terre
  static Future<List<LatLng>> _genererPointsTerre(
    LatLng centre, double rayonKm, int nombre,
  ) async {
    // Générer plus de candidats que nécessaire pour compenser les rejets mer
    final tous = _genererGrille(centre, rayonKm, nombre * 2);
    final surTerre = <LatLng>[];

    for (final point in tous) {
      if (surTerre.length >= nombre) break;
      final estTerre = await _estSurTerre(point);
      if (estTerre) surTerre.add(point);
      // Délai pour respecter le rate limit Nominatim (1 req/s)
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return surTerre;
  }

  // ── VÉRIFICATION TERRE/MER via Nominatim ─────────────────
  static Future<bool> _estSurTerre(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json&zoom=6',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'NEXA-Pastoral-App/1.0',
        'Accept-Language': 'fr',
      }).timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) return true; // en cas d'erreur, on garde le point

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      // Si pas d'adresse → probablement mer
      if (body.containsKey('error')) return false;

      final address = body['address'] as Map<String, dynamic>?;
      if (address == null) return false;

      // Si le type est "sea", "ocean", "water" → rejeter
      final type = body['type']?.toString() ?? '';
      final clazz = body['class']?.toString() ?? '';
      if (type == 'sea' || type == 'ocean' || clazz == 'waterway' || clazz == 'natural') {
        final natural = address['natural']?.toString() ?? '';
        if (natural.contains('sea') || natural.contains('ocean') || natural.contains('water')) {
          return false;
        }
      }

      // Vérifier qu'il y a un pays dans l'adresse (absent si mer)
      return address.containsKey('country') || address.containsKey('country_code');
    } catch (_) {
      return true; // en cas d'erreur réseau, garder le point
    }
  }

  // ── FETCH MODIS VIA NASA ORNL DAAC ───────────────────────
  static Future<double?> _fetchModis(LatLng point) async {
    try {
      final now   = DateTime.now();
      final start = _julianDate(now.subtract(const Duration(days: 32)));
      final end   = _julianDate(now.subtract(const Duration(days: 8)));

      final uri = Uri.parse(
        'https://modis.ornl.gov/rst/api/v1/MOD13Q1/subset'
        '?latitude=${point.latitude.toStringAsFixed(6)}'
        '&longitude=${point.longitude.toStringAsFixed(6)}'
        '&startDate=$start'
        '&endDate=$end'
        '&kmAboveBelow=0'
        '&kmLeftRight=0',
      );

      final resp = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'NEXA-Pastoral-App/1.0',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (body == null) return null;

      final subset = body['subset'] as List?;
      if (subset == null || subset.isEmpty) return null;

      for (final entry in subset) {
        final band = (entry['band'] ?? '').toString();
        if (!band.contains('NDVI')) continue;

        final data = entry['data'] as List?;
        if (data == null || data.isEmpty) continue;

        final raw = (data.first as num?)?.toDouble();
        if (raw == null) continue;

        // MODIS NDVI fill values à exclure :
        // -3000 = fill value (nuage, neige)
        // -28672 = no data
        if (raw <= -2000) return null;

        // MODIS NDVI réel = raw / 10000 → donne -1.0 à 1.0
        final ndvi = raw / 10000.0;

        // Valeur réaliste entre -0.1 et 0.9
        if (ndvi < -0.1 || ndvi > 0.9) return null;

        return ndvi.clamp(-0.1, 0.9);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── FALLBACK : Open-Meteo → proxy NDVI ───────────────────
  // Estimation basée sur pluie récente / ETP
  static Future<double?> _fetchOpenMeteoNdvi(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${point.latitude.toStringAsFixed(4)}'
        '&longitude=${point.longitude.toStringAsFixed(4)}'
        '&daily=precipitation_sum,et0_fao_evapotranspiration'
        '&past_days=30'
        '&forecast_days=0'
        '&timezone=auto',
      );

      final resp = await http.get(uri)
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final daily = body['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final precips = (daily['precipitation_sum'] as List?)
          ?.whereType<num>().toList() ?? [];
      final etos = (daily['et0_fao_evapotranspiration'] as List?)
          ?.whereType<num>().toList() ?? [];

      if (precips.isEmpty || etos.isEmpty) return null;

      final totalPrecip = precips.fold(0.0, (s, v) => s + v.toDouble());
      final totalEto    = etos.fold(0.0,    (s, v) => s + v.toDouble());

      if (totalEto <= 0) return null;

      // Proxy NDVI = (précip/ETP) normalisé dans la plage Sahel (0.05 - 0.45)
      final ratio = (totalPrecip / totalEto).clamp(0.0, 3.0);
      // Mapper ratio → NDVI Sahel réaliste
      final ndvi = 0.05 + (ratio / 3.0) * 0.40;
      return ndvi.clamp(0.05, 0.45);
    } catch (_) {
      return null;
    }
  }

  // ── GRILLE DE POINTS ──────────────────────────────────────
  // Génère des points à distances RÉELLES variables
  static List<LatLng> _genererGrille(
    LatLng centre, double rayonKm, int nombre,
  ) {
    final points = <LatLng>[];
    const azimuts = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];
    // 3 anneaux de distances : 30%, 60%, 90% du rayon
    final distances = [rayonKm * 0.30, rayonKm * 0.60, rayonKm * 0.90];

    for (final dist in distances) {
      for (final az in azimuts) {
        points.add(_deplacer(centre, dist, az));
        if (points.length >= nombre) return points;
      }
    }
    return points;
  }

  // ── HELPERS GÉOGRAPHIQUES ────────────────────────────────

  static LatLng _deplacer(LatLng o, double distKm, double azDeg) {
    const R = 6371.0;
    final d  = distKm / R;
    final az = azDeg * math.pi / 180;
    final la = o.latitude  * math.pi / 180;
    final lo = o.longitude * math.pi / 180;

    final lat2 = math.asin(
      math.sin(la) * math.cos(d) +
      math.cos(la) * math.sin(d) * math.cos(az),
    );
    final lng2 = lo + math.atan2(
      math.sin(az) * math.sin(d) * math.cos(la),
      math.cos(d)  - math.sin(la) * math.sin(lat2),
    );
    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude  * math.pi / 180) *
        math.cos(b.latitude  * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  static String _direction(LatLng from, LatLng to) {
    final angle = math.atan2(
      to.longitude - from.longitude,
      to.latitude  - from.latitude,
    ) * 180 / math.pi;
    if (angle >= -22.5  && angle < 22.5)   return 'Nord';
    if (angle >= 22.5   && angle < 67.5)   return 'Nord-Est';
    if (angle >= 67.5   && angle < 112.5)  return 'Est';
    if (angle >= 112.5  && angle < 157.5)  return 'Sud-Est';
    if (angle >= 157.5  || angle < -157.5) return 'Sud';
    if (angle >= -157.5 && angle < -112.5) return 'Sud-Ouest';
    if (angle >= -112.5 && angle < -67.5)  return 'Ouest';
    return 'Nord-Ouest';
  }

  static String _julianDate(DateTime dt) {
    final doy = dt.difference(DateTime(dt.year, 1, 1)).inDays + 1;
    return 'A${dt.year}${doy.toString().padLeft(3, '0')}';
  }
}