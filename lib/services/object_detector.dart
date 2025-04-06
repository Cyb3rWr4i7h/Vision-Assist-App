import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart'
    as ml_kit;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class DetectedObject {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final Color color;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.color,
  });
}

class ObjectDetector {
  static final List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  // ML Kit object detector
  late ml_kit.ObjectDetector _mlKitObjectDetector;
  bool _isInitialized = false;

  // Singleton pattern
  static final ObjectDetector _instance = ObjectDetector._internal();
  factory ObjectDetector() => _instance;
  ObjectDetector._internal();

  Future<void> _initializeDetector() async {
    if (_isInitialized) return;

    try {
      // For custom models - uncomment when you have model files ready
      /*
      final modelPath = await _getModel('assets/models/object_labeler.tflite');
      final options = ml_kit.LocalObjectDetectorOptions(
        mode: ml_kit.DetectionMode.single,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
      );
      */

      // For now, use the base model provided by ML Kit
      final options = ml_kit.ObjectDetectorOptions(
        mode: ml_kit.DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );

      _mlKitObjectDetector = ml_kit.ObjectDetector(options: options);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing object detector: $e');
      rethrow;
    }
  }

  // Helper method to load custom models if needed
  Future<String> _getModel(String assetPath) async {
    if (path.extension(assetPath) != '.tflite') {
      throw Exception('Model must be a .tflite file');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File(path.join(appDir.path, path.basename(assetPath)));

    // Check if model already exists in app directory
    if (!await modelFile.exists()) {
      // If not, copy from assets
      final modelBytes = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        modelBytes.buffer.asUint8List(
          modelBytes.offsetInBytes,
          modelBytes.lengthInBytes,
        ),
      );
    }

    return modelFile.path;
  }

  Future<List<DetectedObject>> detectObjectsFromImage(File imageFile) async {
    if (!_isInitialized) {
      await _initializeDetector();
    }

    final inputImage = ml_kit.InputImage.fromFile(imageFile);
    final List<DetectedObject> results = [];

    try {
      final List<ml_kit.DetectedObject> detected = await _mlKitObjectDetector
          .processImage(inputImage);

      // Convert ML Kit objects to our custom format
      int colorIndex = 0;
      for (final mlkitObject in detected) {
        for (final label in mlkitObject.labels) {
          if (label.confidence > 0.5) {
            // Only include confident detections
            final boundingBox = mlkitObject.boundingBox;
            final color = _colors[colorIndex % _colors.length];

            results.add(
              DetectedObject(
                label: label.text,
                confidence: label.confidence,
                boundingBox: boundingBox,
                color: color,
              ),
            );

            colorIndex++;
          }
        }
      }

      return results;
    } catch (e) {
      print('Error detecting objects: $e');
      return [];
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    if (_isInitialized) {
      _mlKitObjectDetector.close();
      _isInitialized = false;
    }
  }
}
