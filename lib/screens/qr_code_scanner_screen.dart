import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:share_plus/share_plus.dart';
import 'package:clipboard/clipboard.dart';
import 'package:permission_handler/permission_handler.dart';

class QrCodeScannerScreen extends StatefulWidget {
  const QrCodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrCodeScannerScreen> createState() => _QrCodeScannerScreenState();
}

class _QrCodeScannerScreenState extends State<QrCodeScannerScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _hasPermission = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String _lastScannedData = '';
  String _scanFeedback =
      'Tap anywhere on the screen to start scanning QR codes';
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _checkPermission();

    // Periodic feedback for blind users
    _feedbackTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_lastScannedData.isEmpty) {
        _speakFeedback(_scanFeedback);
      }
    });
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    // Speak initial instructions
    await Future.delayed(const Duration(seconds: 1));
    _speakFeedback(_scanFeedback);
  }

  Future<void> _checkPermission() async {
    final PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
    } else if (status.isDenied) {
      final result = await Permission.camera.request();
      setState(() {
        _hasPermission = result.isGranted;
      });

      if (!result.isGranted) {
        _speakFeedback('Camera permission is required to scan QR codes');
      }
    }
  }

  Future<void> _speakFeedback(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _processQrCode(String data) async {
    if (_isProcessing || data == _lastScannedData) return;

    setState(() {
      _isProcessing = true;
      _lastScannedData = data;
    });

    // Provide haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200);
    }

    // Speak the QR code content
    String feedbackMessage = 'QR code detected. ';

    // Check if it's a URL
    if (data.startsWith('http://') || data.startsWith('https://')) {
      feedbackMessage +=
          'It contains a web link: ${data.replaceAll('https://', '').replaceAll('http://', '')}';
    } else if (data.startsWith('tel:')) {
      feedbackMessage += 'It contains a phone number: ${data.substring(4)}';
    } else if (data.startsWith('mailto:')) {
      feedbackMessage += 'It contains an email address: ${data.substring(7)}';
    } else if (data.startsWith('geo:')) {
      feedbackMessage += 'It contains a location';
    } else {
      feedbackMessage += 'It contains text: $data';
    }

    feedbackMessage +=
        '. Double tap to open, swipe left to copy, swipe right to share, or long press to scan again.';

    await _speakFeedback(feedbackMessage);

    setState(() {
      _scanFeedback = feedbackMessage;
      _isProcessing = false;
    });
  }

  Future<void> _handleQrCodeAction() async {
    if (_lastScannedData.isEmpty) return;

    // Try to handle different types of QR codes
    if (_lastScannedData.startsWith('http://') ||
        _lastScannedData.startsWith('https://')) {
      await _launchUrl(_lastScannedData);
    } else if (_lastScannedData.startsWith('tel:')) {
      await _launchUrl(_lastScannedData);
    } else if (_lastScannedData.startsWith('mailto:')) {
      await _launchUrl(_lastScannedData);
    } else if (_lastScannedData.startsWith('geo:')) {
      await _launchUrl(_lastScannedData);
    } else {
      await _speakFeedback('This QR code contains text: $_lastScannedData');
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _speakFeedback('Could not open this QR code');
      }
    } catch (e) {
      await _speakFeedback('Error opening QR code: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    if (_lastScannedData.isEmpty) return;

    await FlutterClipboard.copy(_lastScannedData);
    await _speakFeedback('Content copied to clipboard');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code content copied to clipboard')),
    );
  }

  Future<void> _shareContent() async {
    if (_lastScannedData.isEmpty) return;

    await Share.share(_lastScannedData, subject: 'QR Code Content');
    await _speakFeedback('Content shared');
  }

  void _resetScanner() {
    setState(() {
      _lastScannedData = '';
      _scanFeedback =
          'Ready to scan a new QR code. Point your camera at a QR code.';
    });
    _speakFeedback(_scanFeedback);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _flutterTts.stop();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_off : Icons.flash_on),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
              await _speakFeedback(
                _torchEnabled
                    ? 'Flashlight turned on'
                    : 'Flashlight turned off',
              );
            },
            tooltip: 'Toggle flashlight',
          ),
        ],
      ),
      body:
          !_hasPermission
              ? _buildPermissionDeniedWidget()
              : _lastScannedData.isNotEmpty
              ? _buildResultWidget()
              : _buildScannerWidget(),
      floatingActionButton:
          _lastScannedData.isNotEmpty
              ? FloatingActionButton(
                onPressed: _resetScanner,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.refresh),
                tooltip: 'Scan another QR code',
              )
              : null,
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Camera permission is required',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await _checkPermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerWidget() {
    return GestureDetector(
      onTap: () {
        _speakFeedback(
          'Scanning for QR codes. Point your camera at a QR code.',
        );
      },
      child: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                  _processQrCode(barcodes[0].rawValue!);
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.7),
            width: double.infinity,
            child: Text(
              _scanFeedback,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultWidget() {
    return GestureDetector(
      onDoubleTap: _handleQrCodeAction,
      onLongPress: _resetScanner,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // Swipe right
            _shareContent();
          } else if (details.primaryVelocity! < 0) {
            // Swipe left
            _copyToClipboard();
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            const Text(
              'QR Code Detected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastScannedData,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.content_copy,
                  label: 'Copy',
                  onPressed: _copyToClipboard,
                ),
                _buildActionButton(
                  icon: Icons.open_in_new,
                  label: 'Open',
                  onPressed: _handleQrCodeAction,
                ),
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onPressed: _shareContent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _scanFeedback,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}
