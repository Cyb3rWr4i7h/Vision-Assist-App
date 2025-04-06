import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vision_assist/services/object_detector.dart';

class ObjectDetectionView extends StatelessWidget {
  final File? imageFile;
  final List<DetectedObject> detectedObjects;
  final VoidCallback onDetectPressed;
  final VoidCallback? onReset;
  final bool isProcessing;
  final List<String>? detectionHistory;

  const ObjectDetectionView({
    Key? key,
    required this.imageFile,
    required this.detectedObjects,
    required this.onDetectPressed,
    required this.isProcessing,
    this.onReset,
    this.detectionHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Display the captured image
        if (imageFile != null) Image.file(imageFile!, fit: BoxFit.cover),

        // Overlay for detected objects
        if (imageFile != null)
          CustomPaint(
            painter: BoundingBoxPainter(
              detectedObjects: detectedObjects,
              imageSize: MediaQuery.of(context).size,
            ),
          ),

        // Loading indicator during processing
        if (isProcessing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Detecting objects...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Object information panel
        if (detectedObjects.isNotEmpty && !isProcessing)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detected ${detectedObjects.length} object${detectedObjects.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...detectedObjects.take(5).map((object) {
                    final confidence = (object.confidence * 100)
                        .toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: object.color,
                            margin: const EdgeInsets.only(right: 8),
                          ),
                          Expanded(
                            child: Text(
                              '${object.label} (${confidence}%)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  if (detectedObjects.length > 5)
                    const Text(
                      '... and more',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Detection history panel
        if (detectionHistory != null &&
            detectionHistory!.isNotEmpty &&
            !isProcessing)
          Positioned(
            bottom: 90,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Recent Detections:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children:
                        detectionHistory!.take(5).map((label) {
                          return Chip(
                            label: Text(label),
                            backgroundColor: Colors.blue.shade700,
                            labelStyle: const TextStyle(color: Colors.white),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          ),

        // Action buttons at the bottom
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: isProcessing ? null : onDetectPressed,
                icon: Icon(
                  isProcessing ? Icons.hourglass_bottom : Icons.search,
                ),
                label: Text(isProcessing ? 'Detecting...' : 'Detect Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (onReset != null)
                ElevatedButton.icon(
                  onPressed: isProcessing ? null : onReset,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Back to Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectedObject> detectedObjects;
  final Size imageSize;

  BoundingBoxPainter({required this.detectedObjects, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final object in detectedObjects) {
      // Scale the bounding box to match the display size
      final rect = Rect.fromLTWH(
        object.boundingBox.left * (size.width / imageSize.width),
        object.boundingBox.top * (size.height / imageSize.height),
        object.boundingBox.width * (size.width / imageSize.width),
        object.boundingBox.height * (size.height / imageSize.height),
      );

      // Draw the bounding box
      final boxPaint =
          Paint()
            ..color = object.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0;
      canvas.drawRect(rect, boxPaint);

      // Prepare the label text
      final confidence = (object.confidence * 100).toStringAsFixed(0);
      final labelText = '${object.label} ${confidence}%';

      // Create a background for the label
      final textBackgroundPaint =
          Paint()
            ..color = object.color
            ..style = PaintingStyle.fill;

      // Measure text size
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );
      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw label background
      final labelBackgroundRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(labelBackgroundRect, textBackgroundPaint);

      // Draw the label text
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
