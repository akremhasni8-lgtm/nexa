# NEXA Flutter App 🌿

Plateforme IA de gestion pastorale offline-first pour les éleveurs africains.

---

## 📁 Architecture complète

```
nexa_app/
│
├── lib/
│   ├── main.dart                          ← Point d'entrée + routing GoRouter
│   │
│   ├── core/
│   │   └── theme/
│   │       └── app_theme.dart             ← Couleurs, typographie, composants réutilisables
│   │                                         (NexaTheme, NexaCard, NexaButton, NexaEyebrow)
│   │
│   ├── models/
│   │   └── models.dart                    ← AnalysisResult, EleveurProfile, SavedZone
│   │                                         + calculs dérivés (GDM, jours, carbone)
│   │
│   ├── services/
│   │   └── ai_service.dart               ← Inférence TFLite offline + mode démo couleurs
│   │
│   └── features/
│       ├── onboarding/
│       │   └── onboarding_screen.dart     ← 3 slides animés (1ère ouverture)
│       │
│       ├── home/
│       │   └── home_screen.dart           ← Dashboard: score santé, CTA analyser, historique
│       │
│       ├── analysis/
│       │   ├── camera_screen.dart         ← Prise photo + galerie + grille scan animée
│       │   └── analysis_screen.dart       ← Config troupeau + overlay inférence IA
│       │
│       ├── map/
│       │   └── map_screen.dart            ← Carte satellite GPS + tracé polygone + surface ha
│       │
│       ├── results/
│       │   └── results_screen.dart        ← Résultats: métriques, graphique, action, carbone
│       │
│       └── history/
│           └── history_screen.dart        ← Historique + graphique évolution + stats globales
│
├── assets/
│   ├── models/
│   │   └── nexa_biomasse.tflite          ← Modèle IA (à convertir depuis .onnx)
│   ├── images/
│   └── animations/
│
└── pubspec.yaml                           ← Toutes les dépendances
```

---

## 🔄 Flow de navigation

```
Onboarding (1ère fois)
       ↓
    Home ──────────────────────────────────┐
     │                                     │
     ├─→ Camera → Analysis → Results       │
     ├─→ Map (tracer zone)                 │
     └─→ History ──────────────────────────┘
```

---

## 🚀 Démarrage rapide

### 1. Prérequis
```bash
flutter --version  # >= 3.16
```

### 2. Installer les dépendances
```bash
cd nexa_app
flutter pub get
```

### 3. Générer les adaptateurs Hive
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Lancer l'app
```bash
flutter run
```

---

## 🧠 Ajouter le vrai modèle TFLite

Convertir le modèle ONNX → TFLite :
```bash
pip install onnx tf2onnx tensorflow
python -m tf2onnx.convert --onnx modeles/nexa_biomasse.onnx --output nexa_biomasse.tflite
```

Puis copier dans `assets/models/nexa_biomasse.tflite` et décommenter le code dans `ai_service.dart`.

---

## 📱 Permissions Android (android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

## 📱 Permissions iOS (ios/Runner/Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>NEXA a besoin de la caméra pour analyser vos pâturages</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>NEXA utilise votre position GPS pour délimiter les zones</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NEXA peut utiliser vos photos pour l'analyse</string>
```

---

## 🌿 Fonctionnalités

| Écran | Fonctionnalité |
|-------|----------------|
| Home | Score santé terres, CTA analyser, historique récent |
| Camera | Photo ou galerie, guide cadrage |
| Analysis | Config espèce/troupeau/surface, inférence IA |
| Map | Carte satellite, tracé polygone GPS, calcul surface ha |
| Results | GDM, jours disponibles, graphique biomasse, crédit carbone |
| History | Évolution score, stats globales, liste complète |

---

## 🔥 Prochaine étape : Firebase

```
Firebase Firestore  → sync analyses multi-appareils
Firebase Auth       → login agent/éleveur
Firebase Storage    → stockage photos
Firebase Analytics  → usage terrain
```