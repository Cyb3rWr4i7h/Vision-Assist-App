# Vision Assist

![Vision Assist Banner](https://via.placeholder.com/800x200?text=Vision+Assist)

## 🔍 Overview

Vision Assist is a comprehensive Flutter application designed to assist visually impaired individuals in navigating their environment and understanding the world around them. The app leverages modern mobile device capabilities like camera, GPS, and AI to provide a suite of accessibility tools that help users perceive and interact with their surroundings.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-%5E3.7.2-blue.svg)](https://flutter.dev/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

## 📱 Key Features

### 🔍 Object Detection
Helps identify objects in the user's surroundings using the device camera. The app provides audio feedback about detected objects and their positions.

![Object Detection Demo](https://via.placeholder.com/400x200?text=Object+Detection+Screenshot)

**Technical Implementation:**
- Uses Google ML Kit Object Detection for real-time object recognition
- Custom UI with camera preview and detection overlays
- Real-time audio feedback using Flutter TTS

### 📖 Text Recognition (OCR)
Identifies and reads text from printed materials, signs, or displays. 

![Text Recognition Demo](https://via.placeholder.com/400x200?text=Text+Recognition+Screenshot)

**Features:**
- Capture images with the camera or select from gallery
- Extract text from images using Google ML Kit
- Have text read aloud using text-to-speech
- Copy recognized text to clipboard
- Share recognized text with other apps

**Technical Implementation:**
- Uses Google ML Kit Text Recognition for accurate OCR
- Processes images at multiple resolutions for better accuracy
- Provides bounding boxes around recognized text
- Hierarchical text extraction (blocks, lines, elements)

### 🎨 Color Detection
Helps identify colors in the user's surroundings using the device camera. The app provides audio feedback about dominant colors detected.

![Color Detection Demo](https://via.placeholder.com/400x200?text=Color+Detection+Screenshot)

**Technical Implementation:**
- Image processing with custom color detection algorithms
- Color naming with closest standard color match
- Announces dominant colors by percentage

### 🗺️ Navigation Assistant
Provides real-time navigation assistance for visually impaired users.

![Navigation Demo](https://via.placeholder.com/400x200?text=Navigation+Screenshot)

**Features:**
- Voice-guided turn-by-turn directions with distance and cardinal orientation
- Initial voice announcement of direction and bearing to destination
- Real-time updates on remaining distance and direction
- Search for destinations by voice input
- Nearby points of interest search (hospitals, bus stops, etc.)
- Automatic rerouting and progress tracking
- Fully accessible interface with voice feedback
- Works with Google Maps APIs or in simplified mode without internet

**Technical Implementation:**
- Google Maps Platform integration for mapping and directions
- Custom turn-by-turn direction algorithm
- Speech-to-text for destination input
- Location services for real-time positioning
- Haptic feedback for directional cues

### 🤖 AI Assistant
An intelligent conversational assistant that can help with various tasks.

![AI Assistant Demo](https://via.placeholder.com/400x200?text=AI+Assistant+Screenshot)

**Features:**
- Answer questions about the user's environment
- Provide contextual help with other app features
- Offer general assistance for visually impaired users
- Uses a completely free on-device solution (no paid APIs required)

**Technical Implementation:**
- On-device conversational AI model
- Voice input and output
- Context-aware responses
- No internet required for basic functionality

## 🛠️ Technical Architecture

Vision Assist follows a modular architecture with clear separation of concerns:

```
lib/
  ├── config/         # Configuration constants and theme data
  ├── models/         # Data models and business logic
  ├── screens/        # UI screens for each feature
  ├── services/       # Services for camera, ML, TTS, etc.
  ├── widgets/        # Reusable UI components
  └── main.dart       # Application entry point
```

### Key Dependencies

- **Flutter SDK ^3.7.2**: Core framework
- **Camera ^0.10.5+9**: Camera access and control
- **Google ML Kit**: Text and object recognition
- **Flutter TTS ^3.8.5**: Text-to-speech capabilities
- **Google Maps Flutter ^2.5.0**: Mapping and navigation
- **Speech-to-Text ^7.0.0**: Voice input processing
- **Location ^5.0.3**: Location services
- **Permission Handler ^11.0.1**: Permission management

## 📋 Prerequisites

- Flutter SDK (^3.7.2 or later)
- Android Studio or Visual Studio Code with Flutter extensions
- An Android or iOS device/emulator for testing
- Google Maps API key for enhanced navigation features
- Google Cloud credentials for certain API features

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/vision_assist.git
   ```

2. **Navigate to the project directory:**
   ```bash
   cd vision_assist
   ```

3. **Set up your API keys:**
   
   Create a `.env` file in the root directory with the following variables:
   ```
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   ```

4. **Install dependencies:**
   ```bash
   flutter pub get
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

## 📖 Usage

### Object Detection
1. Launch the app and select "Object Detection"
2. Point your camera at objects
3. The app will identify objects and speak their names
4. Tap the screen to capture and analyze objects in more detail

### Text Recognition
1. Launch the app and select "Text Recognition"
2. Point your camera at text or select an image from your gallery
3. Tap the "Capture & Recognize" button
4. The app will extract text and display it on screen
5. Use the "Read Text" button to have the text read aloud
6. Use the "Copy" button to copy text to clipboard
7. Use the "Share" button to share text with other apps

### Color Detection
1. Launch the app and select "Color Detection"
2. Point your camera at colored objects
3. The app will identify dominant colors and speak their names
4. Tap the screen to capture and analyze colors in more detail

### Navigation Assistant
1. Launch the app and select "Navigation Assistant"
2. Use the microphone button to speak your destination
3. The app will find the location and generate a route
4. Listen to the initial direction and distance announcement
5. Follow turn-by-turn voice instructions as you walk
6. Receive regular updates on your remaining distance and direction
7. Use bottom buttons to find nearby hospitals or bus stops
8. Tap "My Location" to recenter the map on your current position
9. Tap "Stop" to end navigation

### AI Assistant
1. Launch the app and select "AI Assistant"
2. Type a question or tap the microphone for voice input
3. The assistant will respond to your queries using our free on-device AI solution
4. All processing happens locally on your device - no API keys or internet connection required

## ♿ Accessibility

Vision Assist is specifically designed with accessibility in mind:

- **High contrast interface**: Easy to see for users with low vision
- **Large touch targets**: Makes interaction easier for users with motor difficulties
- **Text-to-speech feedback**: Provides audio information about the app's state and environment
- **Simple, intuitive navigation**: Consistent layout across screens
- **Compatibility with screen readers**: Works with TalkBack and VoiceOver
- **Voice-controlled features**: Hands-free operation throughout the app

## 🧪 Testing

Run the included test suite to verify the app's functionality:

```bash
flutter test
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Google ML Kit for text and object recognition capabilities
- Google Maps Platform for navigation services
- Google Cloud Speech-to-Text for voice recognition
- Flutter TTS for text-to-speech capabilities
- The Flutter team for the wonderful framework
- All contributors who have helped shape this project

## 📞 Contact

If you have any questions, suggestions, or feedback, please open an issue or contact the project maintainer.

---

*Vision Assist: Empowering the visually impaired through technology.*
