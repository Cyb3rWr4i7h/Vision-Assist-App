import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

class ColorDetectionScreen extends StatefulWidget {
  const ColorDetectionScreen({super.key});

  @override
  State<ColorDetectionScreen> createState() => _ColorDetectionScreenState();
}

class _ColorDetectionScreenState extends State<ColorDetectionScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  FlutterTts _flutterTts = FlutterTts();
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  File? _imageFile;

  // Color detection related
  List<IdentifiedColor> _detectedColors = [];

  // Position to detect color (center of screen by default)
  Offset _targetPosition = Offset.zero;
  bool _isPanMode = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          _cameraController = CameraController(
            _cameras.first,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await _cameraController!.initialize();

          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
              // Set target position to center of screen initially
              _targetPosition = Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height / 2,
              );
            });
          }
        }
      } catch (e) {
        print('Camera initialization error: $e');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is needed for color detection'),
          ),
        );
      }
    }
  }

  Future<void> _captureAndDetectColors() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture image
      final XFile photo = await _cameraController!.takePicture();

      // Save image to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/color_detection_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(photo.path).copy(tempFile.path);

      // Update the UI with the captured image
      setState(() {
        _imageFile = tempFile;
      });

      // Process image to detect colors (simulated for now)
      await _processImageForColors();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error during detection: $e')));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Simulated color detection - in a real app, this would analyze the image
  Future<void> _processImageForColors() async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate random but visually distinct colors
    final random = math.Random();
    final List<IdentifiedColor> colors = [];

    // Create a set of predefined colors for realistic detection
    final List<Color> standardColors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
      Colors.white,
    ];

    // Identify 3-5 dominant colors
    final numColors = random.nextInt(3) + 3; // 3 to 5 colors

    for (int i = 0; i < numColors; i++) {
      // Slightly vary the standard colors for more realism
      final baseColor = standardColors[random.nextInt(standardColors.length)];
      final variance = random.nextInt(30) - 15;

      final color = Color.fromARGB(
        255,
        (baseColor.red + variance).clamp(0, 255),
        (baseColor.green + variance).clamp(0, 255),
        (baseColor.blue + variance).clamp(0, 255),
      );

      // Calculate a percentage (ensure they sum to approximately 100%)
      double percentage = 0;
      if (i == numColors - 1) {
        // Make the last color percentage fill the remainder
        percentage =
            100 - colors.map((c) => c.percentage).fold(0, (a, b) => a + b);
      } else {
        // Random percentage, but ensure there's room left for remaining colors
        final remainingPercentage =
            100 - colors.map((c) => c.percentage).fold(0, (a, b) => a + b);
        final maxForThisColor =
            (remainingPercentage - (numColors - i - 1) * 5).toDouble();
        percentage = math.max(
          5.0,
          math.min(maxForThisColor, 5.0 + random.nextInt(30).toDouble()),
        );
      }

      // Find a name for this color
      final colorName = _findColorName(color);

      // Generate hex code
      final hexCode =
          '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}';

      colors.add(
        IdentifiedColor(
          color: color,
          name: colorName,
          hexCode: hexCode.toUpperCase(),
          percentage: percentage,
        ),
      );
    }

    // Sort by percentage
    colors.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Announce the main color
    if (colors.isNotEmpty) {
      final mainColor = colors.first;
      await _flutterTts.speak(
        'The dominant color is ${mainColor.name}, which makes up ${mainColor.percentage.round()}% of the image',
      );
    }

    setState(() {
      _detectedColors = colors;
    });
  }

  // Find a name for a color
  String _findColorName(Color color) {
    // Map of color names to their RGB values
    final colorMap = {
      'Red': Colors.red,
      'Pink': Colors.pink,
      'Purple': Colors.purple,
      'Deep Purple': Colors.deepPurple,
      'Indigo': Colors.indigo,
      'Blue': Colors.blue,
      'Light Blue': Colors.lightBlue,
      'Cyan': Colors.cyan,
      'Teal': Colors.teal,
      'Green': Colors.green,
      'Light Green': Colors.lightGreen,
      'Lime': Colors.lime,
      'Yellow': Colors.yellow,
      'Amber': Colors.amber,
      'Orange': Colors.orange,
      'Deep Orange': Colors.deepOrange,
      'Brown': Colors.brown,
      'Grey': Colors.grey,
      'Blue Grey': Colors.blueGrey,
      'Black': Colors.black,
      'White': Colors.white,
    };

    // Find the color with the smallest distance
    String closestColorName = 'Unknown';
    double minDistance = double.infinity;

    for (final entry in colorMap.entries) {
      final namedColor = entry.value;

      // Calculate Euclidean distance in RGB space
      final rDiff = (color.red - namedColor.red).toDouble();
      final gDiff = (color.green - namedColor.green).toDouble();
      final bDiff = (color.blue - namedColor.blue).toDouble();

      final distance = math.sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);

      if (distance < minDistance) {
        minDistance = distance;
        closestColorName = entry.key;
      }
    }

    return closestColorName;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Detection'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _imageFile = null;
                _detectedColors = [];
              });
            },
            tooltip: 'Reset camera view',
          ),
          IconButton(
            icon: Icon(_isPanMode ? Icons.pan_tool : Icons.touch_app),
            onPressed: () {
              setState(() {
                _isPanMode = !_isPanMode;
              });
            },
            tooltip: _isPanMode ? 'Pan Mode Active' : 'Tap Mode Active',
          ),
        ],
      ),
      body: SafeArea(
        child:
            _isCameraInitialized
                ? _imageFile == null
                    ? _buildCameraPreview()
                    : _buildResultsView()
                : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Initializing camera...'),
                    ],
                  ),
                ),
      ),
      floatingActionButton:
          _imageFile == null && _isCameraInitialized
              ? FloatingActionButton.extended(
                onPressed: _captureAndDetectColors,
                backgroundColor: Colors.orange,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture & Detect'),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    return GestureDetector(
      onTapDown:
          _isPanMode
              ? null
              : (details) {
                setState(() {
                  _targetPosition = details.localPosition;
                });
              },
      onPanUpdate:
          _isPanMode
              ? (details) {
                setState(() {
                  _targetPosition = details.localPosition;
                });
              }
              : null,
      child: Stack(
        children: [
          // Camera preview
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CameraPreview(_cameraController!),
            ),
          ),

          // Target crosshair
          CustomPaint(
            painter: CrosshairPainter(targetPosition: _targetPosition),
            size: Size.infinite,
          ),

          // Instructions overlay
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isPanMode
                      ? 'Drag to move the target'
                      : 'Tap to set the target',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        // Display the captured image
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
        ),

        // Display detected colors
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Detected Colors:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child:
                      _isProcessing
                          ? const Center(child: CircularProgressIndicator())
                          : _detectedColors.isEmpty
                          ? const Center(child: Text('No colors detected'))
                          : ListView.builder(
                            itemCount: _detectedColors.length,
                            itemBuilder: (context, index) {
                              final color = _detectedColors[index];
                              return ColorListItem(
                                color: color,
                                onTap: () {
                                  _flutterTts.speak(
                                    'This is ${color.name} with hex code ${color.hexCode}',
                                  );
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class IdentifiedColor {
  final Color color;
  final String name;
  final String hexCode;
  final double percentage;

  IdentifiedColor({
    required this.color,
    required this.name,
    required this.hexCode,
    required this.percentage,
  });
}

class ColorListItem extends StatelessWidget {
  final IdentifiedColor color;
  final VoidCallback onTap;

  const ColorListItem({super.key, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Color swatch
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.color,
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              // Color information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      color.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hex: ${color.hexCode}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Percentage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${color.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CrosshairPainter extends CustomPainter {
  final Offset targetPosition;

  CrosshairPainter({required this.targetPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    // Draw crosshair
    const crosshairSize = 20.0;

    // Horizontal line
    canvas.drawLine(
      Offset(targetPosition.dx - crosshairSize, targetPosition.dy),
      Offset(targetPosition.dx + crosshairSize, targetPosition.dy),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(targetPosition.dx, targetPosition.dy - crosshairSize),
      Offset(targetPosition.dx, targetPosition.dy + crosshairSize),
      paint,
    );

    // Draw circle
    canvas.drawCircle(targetPosition, 10, paint);
  }

  @override
  bool shouldRepaint(CrosshairPainter oldDelegate) {
    return targetPosition != oldDelegate.targetPosition;
  }
}
