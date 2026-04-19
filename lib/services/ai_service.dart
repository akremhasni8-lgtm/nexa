import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/models.dart';

class AIService {
  // static const String _modelPath = 'assets/models/nexa_biomasse.tflite';
  static const int _inputSize = 260; // EfficientNet-B2

  // Normalisation ImageNet
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std  = [0.229, 0.224, 0.225];

  bool _isInitialized = false;

  // ── INITIALISATION ───────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Interpréteur TFLite initialisé ici quand le modèle sera disponible
    // Pour le moment : mode demo avec valeurs simulées
    _isInitialized = true;
  }

  // ── ANALYSE D'IMAGE ──────────────────────────────────────
  Future<Map<String, double>> analyzeImage(String imagePath) async {
    await initialize();

    // Charger et prétraiter l'image
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) throw Exception('Impossible de lire l\'image');

    // Redimensionner
    image = img.copyResize(image, width: _inputSize, height: _inputSize);

    // ── MODE RÉEL : inférence TFLite ──────────────────────
    // Décommenter quand le modèle .tflite est dans assets/models/
    /*
    final interpreter = await Interpreter.fromAsset(_modelPath);
    final input = _preprocessImage(image);
    final output = List.filled(3, 0.0).reshape([1, 3]);
    interpreter.run(input, output);
    return {
      'green':  output[0][0].toDouble().clamp(0, double.infinity),
      'clover': output[0][1].toDouble().clamp(0, double.infinity),
      'dead':   output[0][2].toDouble().clamp(0, double.infinity),
    };
    */

    // ── MODE DÉMO : simulation basée sur l'analyse des couleurs ──
    return _analyzeColors(image);
  }

  // Analyse heuristique des couleurs pour la démo
  Map<String, double> _analyzeColors(img.Image image) {
    double greenPixels = 0, brownPixels = 0, totalPixels = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        // Détection verdure (NDVI simplifié)
        if (g > r * 1.1 && g > b * 1.1 && g > 0.2) {
          greenPixels++;
        } else if (r > g * 0.9 && b < 0.3) {
          brownPixels++;
        }
        totalPixels++;
      }
    }

    final greenRatio  = totalPixels > 0 ? greenPixels / totalPixels : 0.5;
    final brownRatio  = totalPixels > 0 ? brownPixels / totalPixels : 0.2;

    // Valeurs calibrées sur le dataset CSIRO (g/0.25m²)
    final green  = (greenRatio * 35.0 + 5.0).clamp(2.0, 45.0);
    final clover = (greenRatio * 12.0 + 2.0).clamp(1.0, 18.0);
    final dead   = (brownRatio * 15.0 + 3.0).clamp(1.0, 25.0);

    return {
      'green':  green,
      'clover': clover,
      'dead':   dead,
    };
  }

  // Prétraitement pour TFLite [1, 260, 260, 3]
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final input = List.generate(
      1, (_) => List.generate(
        _inputSize, (y) => List.generate(
          _inputSize, (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r / 255.0 - _mean[0]) / _std[0],
              (pixel.g / 255.0 - _mean[1]) / _std[1],
              (pixel.b / 255.0 - _mean[2]) / _std[2],
            ];
          },
        ),
      ),
    );
    return input;
  }
}
