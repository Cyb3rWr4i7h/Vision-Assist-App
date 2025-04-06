import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'package:vision_assist/services/ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  final List<ChatMessage> _messages = [];
  final AIService _aiService = AIService();

  // Speech to text properties
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  bool _speechEnabled = false;

  bool _isTyping = false;
  bool _isReadingResponse = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeAI();
    _initializeSpeech();
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    // Check microphone permission
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        // Initialize speech to text
        _speechEnabled = await _speech.initialize(
          onStatus: (status) => _onSpeechStatus(status),
          onError:
              (errorNotification) =>
                  print('Speech recognition error: $errorNotification'),
        );

        if (_speechEnabled) {
          print('Speech recognition initialized successfully');
        } else {
          print('Failed to initialize speech recognition');
        }
      } catch (e) {
        print('Error initializing speech recognition: $e');
      }
    } else {
      print('Microphone permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is needed for voice input'),
          ),
        );
      }
    }
  }

  // Handle speech status changes
  void _onSpeechStatus(String status) {
    print('Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      // Process the recognized text if we have any
      if (_lastWords.isNotEmpty) {
        _handleSubmitted(_lastWords);
        _lastWords = '';
      }
    }
  }

  // Start listening for speech input
  void _startListening() async {
    // Stop any ongoing TTS to avoid conflict
    await _stopReading();

    if (_speechEnabled) {
      setState(() {
        _isListening = true;
      });

      try {
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;

              // Update text field with recognized words in real-time
              _messageController.text = _lastWords;

              // Move cursor to the end
              _messageController.selection = TextSelection.fromPosition(
                TextPosition(offset: _messageController.text.length),
              );
            });
          },
          listenFor: const Duration(seconds: 30), // Max listening time
          pauseFor: const Duration(seconds: 3), // Stop after this much silence
          partialResults: true,
          localeId: 'en_US',
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listening...')));
      } catch (e) {
        print('Error listening: $e');
        setState(() {
          _isListening = false;
        });
      }
    } else {
      print('Speech recognition not available');
      // Try to initialize again
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
    if (!_speech.isListening) return;

    try {
      await _speech.stop();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _initializeAI() async {
    await _aiService.initialize();

    // Add welcome message
    _addAssistantMessage(await _aiService.sendMessage('Hello'));
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _stopReading() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isReadingResponse = false;
      });
    }
  }

  Future<void> _readText(String text) async {
    // Don't read text if we're listening to speech
    if (text.isEmpty || _isListening) return;

    setState(() {
      _isReadingResponse = true;
    });

    try {
      await _flutterTts.speak(text);

      // For text of average length, estimate speech duration
      final wordCount =
          text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final estimatedDuration = Duration(
        milliseconds: wordCount * 300,
      ); // ~300ms per word

      await Future.delayed(estimatedDuration);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reading text: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReadingResponse = false;
        });
      }
    }
  }

  void _handleSubmitted(String text) async {
    _messageController.clear();

    if (text.trim().isEmpty) return;

    // Add user message
    _addUserMessage(text);

    // Simulate typing
    setState(() {
      _isTyping = true;
    });

    // Scroll to bottom
    await _scrollToBottom();

    // Get response from AI service
    final response = await _aiService.sendMessage(text);

    // Add assistant response
    _addAssistantMessage(response);

    setState(() {
      _isTyping = false;
    });

    await _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
    });
  }

  void _addAssistantMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(text: message, isUser: false));
    });

    // Auto-read assistant responses only if not currently listening
    if (!_isListening) {
      _readText(message);
    }
  }

  void _clearConversation() {
    setState(() {
      // Keep only the first welcome message
      if (_messages.isNotEmpty) {
        final firstMessage = _messages.first;
        _messages.clear();
        _messages.add(firstMessage);
      }

      // Clear conversation history in AIService
      _aiService.clearConversation();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Conversation cleared')));
  }

  Future<void> _scrollToBottom() async {
    // Add a small delay to ensure the list is updated
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add tap-to-listen functionality on the entire screen
      onTap: () {
        // Skip if we're already listening or we're in the middle of text input
        if (_isListening || _messageController.text.isNotEmpty) return;
        _startListening();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Assistant'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          actions: [
            if (_isListening)
              IconButton(
                icon: const Icon(Icons.mic_off),
                onPressed: _stopListening,
                tooltip: 'Stop listening',
              ),
            if (_isReadingResponse)
              IconButton(
                icon: const Icon(Icons.stop_circle),
                onPressed: _stopReading,
                tooltip: 'Stop reading',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearConversation,
              tooltip: 'Clear conversation',
            ),
          ],
        ),
        body: Column(
          children: [
            // Microphone status indicator
            if (_isListening)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.purple.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastWords.isEmpty
                            ? 'Listening...'
                            : 'Heard: $_lastWords',
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: _stopListening,
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length,
                itemBuilder: (_, int index) => _messages[index],
              ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    SizedBox(
                      width: 45,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.purple,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1.0),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: Colors.purple.shade200),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: _handleSubmitted,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.purple,
              ),
              onPressed: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              tooltip: _isListening ? 'Stop listening' : 'Start voice input',
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.purple),
                onPressed: () => _handleSubmitted(_messageController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({super.key, required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final messageAlignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final messageColor = isUser ? Colors.purple.shade100 : Colors.grey.shade100;
    final textColor = isUser ? Colors.purple.shade900 : Colors.black87;
    final avatarWidget =
        isUser
            ? const CircleAvatar(
              backgroundColor: Colors.purple,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            )
            : const CircleAvatar(
              backgroundColor: Colors.purple,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) avatarWidget,
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: messageAlignment,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: messageColor,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 2,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  child: Text(text, style: TextStyle(color: textColor)),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4.0,
                    left: 4.0,
                    right: 4.0,
                  ),
                  child: Text(
                    isUser ? 'You' : 'Vision AI',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) avatarWidget,
        ],
      ),
    );
  }
}
