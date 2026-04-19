import 'package:hive/hive.dart';

part 'models.g.dart';

// ── RÉSULTAT D'ANALYSE ────────────────────────────────────

@HiveType(typeId: 0)
class AnalysisResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String imagePath;

  @HiveField(3)
  final double greenG;     // Végétation verte (g/quadrat)

  @HiveField(4)
  final double cloverG;    // Trèfle (g/quadrat)

  @HiveField(5)
  final double deadG;      // Matière morte (g/quadrat)

  @HiveField(6)
  final double surfaceHa;  // Surface tracée sur la carte

  @HiveField(7)
  final int troupeauSize;

  @HiveField(8)
  final String espece;

  @HiveField(9)
  final double? latitude;

  @HiveField(10)
  final double? longitude;

  @HiveField(11)
  final String? zoneName;

  @HiveField(20) // utilise le prochain index disponible
  String? userId;

  AnalysisResult({
    required this.id,
    required this.timestamp,
    required this.imagePath,
    required this.greenG,
    required this.cloverG,
    required this.deadG,
    required this.surfaceHa,
    required this.troupeauSize,
    required this.espece,
    this.latitude,
    this.longitude,
    this.zoneName,
    this.userId,
  });

  // ── CALCULS DÉRIVÉS ──────────────────────────────────────

  double get gdmG => greenG + cloverG;
  double get totalG => gdmG + deadG;

  double get qualitePct => totalG > 0 ? (gdmG / totalG * 100).clamp(0, 100) : 0;

  // Densité réelle g/m² (quadrat CSIRO = 0.25 m²)
  double get densiteGm2 => gdmG / 0.25;

  // Biomasse totale utilisable sur la zone (50% taux d'utilisation)
  double get biomasseUtilisableG => densiteGm2 * surfaceHa * 10000 * 0.50;

  // Consommation journalière du troupeau (g)
  double get consoJourG {
    const Map<String, double> conso = {
      'Vache': 10000,
      'Mouton': 1000,
      'Chèvre': 875,
      'Chameau': 7500,
    };
    return (conso[espece] ?? 5000) * troupeauSize;
  }

  int get joursDisponibles =>
      consoJourG > 0 ? (biomasseUtilisableG / consoJourG).floor() : 0;

  PastureStatus get statut {
    if (joursDisponibles >= 14) return PastureStatus.excellent;
    if (joursDisponibles >= 7)  return PastureStatus.bon;
    if (joursDisponibles >= 3)  return PastureStatus.attention;
    return PastureStatus.critique;
  }

  // Score santé des terres (0-100)
  double get scoreSante {
    double score = qualitePct * 0.6;
    if (joursDisponibles >= 14) score += 40;
    else if (joursDisponibles >= 7) score += 25;
    else if (joursDisponibles >= 3) score += 10;
    return score.clamp(0, 100);
  }

  // Estimation crédit carbone (tCO2/ha/an) — simplifié
  double get creditCarboneTonne => surfaceHa * scoreSante / 100 * 1.5;
  double get creditCarboneUSD => creditCarboneTonne * 20; // 20$/tonne
}

enum PastureStatus { excellent, bon, attention, critique }

// ── STATUT DE ROTATION D'UNE ZONE ───────────────────────

@HiveType(typeId: 3)
enum ZoneStatus {
  @HiveField(0)
  active,      // Troupeau ici maintenant
  @HiveField(1)
  attente,     // Pas encore utilisée
  @HiveField(2)
  repos,       // En récupération après utilisation
  @HiveField(3)
  prete,       // Récupérée — disponible
  @HiveField(4)
  finDeCycle,  // Bientôt à quitter
  @HiveField(5)
  epuisee,     // Critique — ne pas utiliser
}


extension PastureStatusExt on PastureStatus {
  String get label {
    switch (this) {
      case PastureStatus.excellent: return 'Excellente zone';
      case PastureStatus.bon:       return 'Bonne zone';
      case PastureStatus.attention: return 'Zone en fin de cycle';
      case PastureStatus.critique:  return 'Zone épuisée';
    }
  }

  String get action {
    switch (this) {
      case PastureStatus.excellent:
        return 'Restez sur cette zone. Planifiez le déplacement dans 10 jours.';
      case PastureStatus.bon:
        return 'Préparez le prochain déplacement dans 4 jours.';
      case PastureStatus.attention:
        return 'Identifiez une nouvelle zone dès aujourd\'hui.';
      case PastureStatus.critique:
        return 'Quittez cette zone immédiatement pour préserver le sol.';
    }
  }

  String get emoji {
    switch (this) {
      case PastureStatus.excellent: return '🟢';
      case PastureStatus.bon:       return '🟡';
      case PastureStatus.attention: return '🟠';
      case PastureStatus.critique:  return '🔴';
    }
  }
}

// ── PROFIL ÉLEVEUR ────────────────────────────────────────

@HiveType(typeId: 1)
class EleveurProfile extends HiveObject {
  @HiveField(0)
  String nom;

  @HiveField(1)
  String espece;

  @HiveField(2)
  int troupeauSize;

  @HiveField(3)
  String region;

  @HiveField(4)
  bool isNomade;

  @HiveField(5)
  DateTime createdAt;

  EleveurProfile({
    required this.nom,
    required this.espece,
    required this.troupeauSize,
    required this.region,
    required this.isNomade,
    required this.createdAt,
  });
}

// ── ZONE DE PÂTURAGE SAUVEGARDÉE ─────────────────────────

@HiveType(typeId: 2)
class SavedZone extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final double surfaceHa;

  @HiveField(5)
  final List<double> polygonLats;

  @HiveField(6)
  final List<double> polygonLngs;

  @HiveField(7)
  DateTime? lastAnalyzed;

  @HiveField(8)
  double? lastScore;

  @HiveField(9)
  ZoneStatus status;

  @HiveField(10)
  int joursDisponibles;

  @HiveField(11)
  bool isNext;

  @HiveField(12)
  DateTime? dateDebutPaturage;

  @HiveField(13)
  AnalysisResult? derniereAnalyse;

  SavedZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.surfaceHa,
    required this.polygonLats,
    required this.polygonLngs,
    this.lastAnalyzed,
    this.lastScore,
    this.status = ZoneStatus.attente,
    this.joursDisponibles = 0,
    this.isNext = false,
    this.dateDebutPaturage,
    this.derniereAnalyse,
  });

  SavedZone copyWith({
    String? name,
    ZoneStatus? status,
    AnalysisResult? derniereAnalyse,
    int? joursDisponibles,
    bool? isNext,
    DateTime? dateDebutPaturage,
    DateTime? lastAnalyzed,
    double? lastScore,
  }) {
    return SavedZone(
      id: id,
      name: name ?? this.name,
      latitude: latitude,
      longitude: longitude,
      surfaceHa: surfaceHa,
      polygonLats: polygonLats,
      polygonLngs: polygonLngs,
      status: status ?? this.status,
      derniereAnalyse: derniereAnalyse ?? this.derniereAnalyse,
      joursDisponibles: joursDisponibles ?? this.joursDisponibles,
      isNext: isNext ?? this.isNext,
      dateDebutPaturage: dateDebutPaturage ?? this.dateDebutPaturage,
      lastAnalyzed: lastAnalyzed ?? this.lastAnalyzed,
      lastScore: lastScore ?? this.lastScore,
    );
  }
}

