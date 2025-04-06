import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vision_assist/services/object_detector.dart';
import 'package:vision_assist/widgets/object_detection_view.dart';
import 'dart:io';
import 'dart:async';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  FlutterTts _flutterTts = FlutterTts();
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  bool _isContinuousDetection = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;
  Timer? _continuousDetectionTimer;

  // Object detection related
  final ObjectDetector _objectDetector = ObjectDetector();
  File? _imageFile;
  List<DetectedObject> _detectedObjects = [];

  // Store the detection history for tracking objects over time
  List<String> _detectionHistory = [];
  final int _maxHistoryItems = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeTts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed - handle camera resources
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopContinuousDetection();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
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
          // Use the selected camera index, or default to 0 if out of bounds
          _selectedCameraIndex =
              _selectedCameraIndex < _cameras.length ? _selectedCameraIndex : 0;

          _cameraController = CameraController(
            _cameras[_selectedCameraIndex],
            ResolutionPreset.high,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );

          await _cameraController!.initialize();

          // Check if flash is available
          if (_cameraController!.value.isInitialized) {
            try {
              if (_cameraController!.description.lensDirection ==
                  CameraLensDirection.back) {
                // Flash is typically only available on the back camera
                await _cameraController!.setFlashMode(
                  _isFlashOn ? FlashMode.torch : FlashMode.off,
                );
              }
            } catch (e) {
              print('Flash not available: $e');
              _isFlashOn = false;
            }
          }

          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }

          // Resume continuous detection if it was on
          if (_isContinuousDetection) {
            _startContinuousDetection();
          }
        }
      } catch (e) {
        print('Camera initialization error: $e');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is needed for object detection'),
          ),
        );
      }
    }
  }

  Future<void> _toggleCameraDirection() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No secondary camera available')),
      );
      return;
    }

    // Stop continuous detection during camera switch
    final wasContinuous = _isContinuousDetection;
    _stopContinuousDetection();

    // Toggle between front and back cameras
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    // Dispose current controller
    await _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _isCameraInitialized = false;
      _isFlashOn = false; // Reset flash when switching camera
    });

    // Initialize with new camera
    await _initializeCamera();

    // Resume continuous detection if it was on
    if (wasContinuous && _isCameraInitialized) {
      _startContinuousDetection();
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.description.lensDirection !=
            CameraLensDirection.back) {
      // Flash is typically only available on back cameras
      return;
    }

    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      print('Error toggling flash: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flash control error: $e')));
    }
  }

  void _startContinuousDetection() {
    if (_continuousDetectionTimer != null) {
      _continuousDetectionTimer!.cancel();
    }

    // Run detection every 2 seconds
    _continuousDetectionTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _detectObjects(),
    );

    setState(() {
      _isContinuousDetection = true;
    });

    // Feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Continuous detection enabled')),
    );
  }

  void _stopContinuousDetection() {
    if (_continuousDetectionTimer != null) {
      _continuousDetectionTimer!.cancel();
      _continuousDetectionTimer = null;
    }

    setState(() {
      _isContinuousDetection = false;
    });
  }

  void _toggleContinuousDetection() {
    if (_isContinuousDetection) {
      _stopContinuousDetection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Continuous detection disabled')),
      );
    } else {
      _startContinuousDetection();
    }
  }

  Future<void> _detectObjects() async {
    if (_isDetecting ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isDetecting = true;
    });

    try {
      // Capture image
      final XFile photo = await _cameraController!.takePicture();

      // Save image to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/object_detection_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(photo.path).copy(tempFile.path);

      // Update the UI with the captured image
      setState(() {
        _imageFile = tempFile;
      });

      // Perform object detection
      final detectedObjects = await _objectDetector.detectObjectsFromImage(
        tempFile,
      );

      // Update UI and detect history only if we have new results
      // and we're not in continuous mode (to avoid UI flicker)
      if (detectedObjects.isNotEmpty || !_isContinuousDetection) {
        // Find new objects that weren't in previous detection
        final Set<String> currentLabels =
            detectedObjects.map((obj) => obj.label).toSet();

        final Set<String> previousLabels =
            _detectedObjects.isEmpty
                ? {}
                : _detectedObjects.map((obj) => obj.label).toSet();

        final Set<String> newObjects = currentLabels.difference(previousLabels);

        // Update the UI with the detected objects
        setState(() {
          _detectedObjects = detectedObjects;

          // Update detection history with new objects
          if (newObjects.isNotEmpty) {
            _detectionHistory.addAll(newObjects);
            // Keep history at reasonable size
            if (_detectionHistory.length > _maxHistoryItems) {
              _detectionHistory = _detectionHistory.sublist(
                _detectionHistory.length - _maxHistoryItems,
              );
            }
          }
        });

        // Speak the detected objects if there are new ones
        if (newObjects.isNotEmpty && !_isContinuousDetection) {
          final objectsText =
              newObjects.length == 1
                  ? 'I see a ${newObjects.first}'
                  : 'I see ${newObjects.length} objects: ${newObjects.join(", ")}';
          await _flutterTts.speak(objectsText);
        } else if (detectedObjects.isEmpty && !_isContinuousDetection) {
          await _flutterTts.speak('No objects detected');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error during detection: $e')));
    } finally {
      setState(() {
        _isDetecting = false;
      });

      // In continuous mode, return to the camera preview after detection
      if (_isContinuousDetection && mounted) {
        setState(() {
          _imageFile = null;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopContinuousDetection();
    _cameraController?.dispose();
    _flutterTts.stop();
    _objectDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Camera switch button
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _toggleCameraDirection,
              tooltip: 'Switch camera',
            ),
          // Flash toggle
          if (_cameraController?.description.lensDirection ==
              CameraLensDirection.back)
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
              tooltip: 'Toggle flash',
            ),
          // Continuous detection toggle
          IconButton(
            icon: Icon(
              _isContinuousDetection
                  ? Icons.autorenew
                  : Icons.autorenew_outlined,
            ),
            onPressed: _toggleContinuousDetection,
            tooltip: 'Toggle continuous detection',
          ),
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _imageFile = null;
                _detectedObjects = [];
                // Don't clear history
              });
            },
            tooltip: 'Reset camera view',
          ),
        ],
      ),
      body: SafeArea(
        child:
            _isCameraInitialized
                ? _imageFile == null
                    ? _buildCameraPreview()
                    : ObjectDetectionView(
                      imageFile: _imageFile,
                      detectedObjects: _detectedObjects,
                      onDetectPressed: _detectObjects,
                      isProcessing: _isDetecting,
                      detectionHistory: _detectionHistory,
                      onReset: () {
                        setState(() {
                          _imageFile = null;
                        });
                      },
                    )
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
                onPressed: _detectObjects,
                backgroundColor: Colors.blue,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture & Detect'),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // Camera preview
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Instructions overlay
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isContinuousDetection
                    ? 'Continuous detection mode ON'
                    : 'Point camera at objects to detect',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),

        // Recently detected objects history
        if (_detectionHistory.isNotEmpty)
          Positioned(
            bottom: 80,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Recently detected:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _detectionHistory.take(3).join(', '),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
