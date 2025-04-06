import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:vision_assist/screens/object_detection_screen.dart';
import 'package:vision_assist/screens/color_detection_screen.dart';
import 'package:vision_assist/screens/text_recognition_screen.dart';
import 'package:vision_assist/screens/ai_assistant_screen.dart';
import 'package:vision_assist/screens/navigation_screen.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Validate Google Cloud Speech-to-Text service account credentials
  try {
    // Load credentials from file
    final String jsonContent = await rootBundle.loadString(
      'coral-idiom-448917-f6-59bf3582a49c.json',
    );
    final Map<String, dynamic> credentialsJson = json.decode(jsonContent);

    // Verify the file contains the expected fields
    if (!_verifyCredentials(credentialsJson)) {
      debugPrint('⚠️ Service account credentials file missing required fields');
    } else {
      // Try to create a valid service account credentials object
      final accountCredentials = ServiceAccountCredentials.fromJson(
        credentialsJson,
      );

      // Define the scopes we need
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

      // Attempt to get a token to validate credentials (we don't save it now, just testing)
      try {
        final client = http.Client();
        try {
          debugPrint('Validating service account credentials...');
          await obtainAccessCredentialsViaServiceAccount(
            accountCredentials,
            scopes,
            client,
          );
          debugPrint('✅ Successfully validated service account credentials');
        } finally {
          client.close();
        }
      } catch (e) {
        debugPrint('⚠️ Error validating service account credentials: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error loading service account credentials: $e');
  }

  runApp(const MyApp());
}

// Helper function to verify if credentials contain required fields
bool _verifyCredentials(Map<String, dynamic> credentials) {
  final requiredFields = [
    'type',
    'project_id',
    'private_key_id',
    'private_key',
    'client_email',
    'client_id',
  ];

  for (final field in requiredFields) {
    if (!credentials.containsKey(field) || credentials[field] == null) {
      debugPrint('⚠️ Missing required field in credentials: $field');
      return false;
    }
  }

  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Assist',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Text-to-speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  String _instructionsText = '';

  // Speech-to-text
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTts();
    _initializeSpeech();
    // Start speaking instructions after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _speakInstructions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in background
      _stopSpeaking();
      if (_isListening) {
        _speech.stop();
        setState(() => _isListening = false);
      }
    }
  }

  // Initialize text-to-speech
  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        _speechEnabled = await _speech.initialize(
          onStatus: (status) {
            print('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted) {
                setState(() => _isListening = false);
                _processCommand(_recognizedText);
                _recognizedText = '';
              }
            }
          },
          onError: (error) {
            print('Speech recognition error: $error');
            if (error.errorMsg == 'error_speech_timeout') {
              // Handle timeout by stopping listening and showing a message
              if (mounted) {
                setState(() => _isListening = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Listening timed out. Please try again.'),
                  ),
                );
              }
            }
          },
          debugLogging: true,
        );
        print('Speech recognition initialized: $_speechEnabled');
      } catch (e) {
        print('Error initializing speech recognition: $e');
      }
    } else {
      print('Microphone permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is needed for voice commands'),
          ),
        );
      }
    }
  }

  // Speak the instruction text
  Future<void> _speakInstructions() async {
    if (_isSpeaking) {
      await _stopSpeaking();
    }

    const instructions = '''
Welcome to Vision Assist. This app has 5 main functions:
- Say "Open Object Detection" to detect objects around you
- Say "Open Text Recognition" to read text
- Say "Open Color Detection" to identify colors
- Say "Open AI Assistant" to chat with our AI
- Say "Open Navigation" for assistance with navigation
Tap anywhere on the screen to activate voice recognition.
    ''';

    setState(() {
      _instructionsText = instructions;
      _isSpeaking = true;
    });

    await _flutterTts.speak(instructions);
  }

  // Stop speaking
  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  // Start listening for commands
  Future<void> _startListening() async {
    // Don't start if already listening
    if (_isListening) return;

    // Stop speaking if needed
    await _stopSpeaking();

    if (_speechEnabled) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(
            seconds: 60,
          ), // Increased from 15 to 60 seconds
          pauseFor: const Duration(
            seconds: 10,
          ), // Increased from 3 to 10 seconds
          partialResults: true,
          localeId: 'en_US',
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listening for command...')),
        );
      } catch (e) {
        print('Error starting speech recognition: $e');
        setState(() => _isListening = false);
      }
    } else {
      // Try to initialize again if it failed previously
      await _initializeSpeech();
      if (!_speechEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  // Stop listening
  void _stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }

    setState(() => _isListening = false);
  }

  // Process the recognized command
  void _processCommand(String command) {
    if (command.isEmpty) return;

    final lowerCommand = command.toLowerCase();
    print('Processing command: $lowerCommand');

    if (lowerCommand.contains('object') || lowerCommand.contains('detection')) {
      _navigateTo(const ObjectDetectionScreen());
    } else if (lowerCommand.contains('text') ||
        lowerCommand.contains('recognition')) {
      _navigateTo(const TextRecognitionScreen());
    } else if (lowerCommand.contains('color')) {
      _navigateTo(const ColorDetectionScreen());
    } else if (lowerCommand.contains('ai') ||
        lowerCommand.contains('assistant')) {
      _navigateTo(const AIAssistantScreen());
    } else if (lowerCommand.contains('nav') ||
        lowerCommand.contains('navigation')) {
      _navigateTo(const NavigationScreen());
    } else if (lowerCommand.contains('help') ||
        lowerCommand.contains('instructions')) {
      _speakInstructions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command not recognized. Please try again.'),
        ),
      );

      // Speak the error message
      _flutterTts.speak('Command not recognized. Please try again.');
    }
  }

  // Navigate to a specific screen
  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Assist'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _speakInstructions,
            tooltip: 'Instructions',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_isSpeaking) {
            _stopSpeaking();
          } else if (!_isListening) {
            _startListening();
          }
        },
        behavior:
            HitTestBehavior.opaque, // Makes sure taps are detected everywhere
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Text(
                'Vision Assist',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Listening status text - make it tappable too
              GestureDetector(
                onTap: () {
                  if (_isSpeaking) {
                    _stopSpeaking();
                  } else if (!_isListening) {
                    _startListening();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isListening
                            ? Colors.deepPurple.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isListening
                        ? 'Listening: $_recognizedText'
                        : 'Tap anywhere to activate voice commands',
                    style: TextStyle(
                      fontSize: 18,
                      color: _isListening ? Colors.deepPurple : Colors.black54,
                      fontWeight:
                          _isListening ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Voice activation indicator - make it tappable as a button
              GestureDetector(
                onTap: () {
                  if (_isSpeaking) {
                    _stopSpeaking();
                  } else if (!_isListening) {
                    _startListening();
                  } else {
                    _stopListening();
                  }
                },
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isListening ? 150 : 100,
                    height: _isListening ? 150 : 100,
                    decoration: BoxDecoration(
                      color:
                          _isListening
                              ? Colors.deepPurple.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow:
                          _isListening
                              ? [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: _isListening ? 80 : 50,
                      color: _isListening ? Colors.deepPurple : Colors.grey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Display the instructions text - make this tappable too
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isSpeaking) {
                      _stopSpeaking();
                    } else if (!_isListening) {
                      _startListening();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _instructionsText,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),

              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSpeaking
                          ? Icons.volume_up
                          : _isListening
                          ? Icons.mic
                          : Icons.volume_off,
                      color:
                          _isSpeaking
                              ? Colors.blue
                              : _isListening
                              ? Colors.deepPurple
                              : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSpeaking
                          ? 'Speaking...'
                          : _isListening
                          ? 'Listening...'
                          : 'Ready',
                      style: TextStyle(
                        color:
                            _isSpeaking
                                ? Colors.blue
                                : _isListening
                                ? Colors.deepPurple
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
