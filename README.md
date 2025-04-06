# Vision Assist

A Flutter application designed to assist visually impaired individuals in navigating their environment and understanding the world around them. The app provides multiple features that use the device camera to help users perceive their surroundings.

## Features

### 1. Object Detection
Helps identify objects in the user's surroundings using the device camera. The app provides audio feedback about detected objects and their positions.

### 2. Text Recognition (OCR)
Identifies and reads text from printed materials, signs, or displays. Users can:
- Capture images with the camera or select from gallery
- Extract text from images using Google ML Kit
- Have text read aloud using text-to-speech
- Copy recognized text to clipboard
- Share recognized text with other apps

### 3. Color Detection
Helps identify colors in the user's surroundings using the device camera. The app provides audio feedback about dominant colors detected.

### 4. Navigation Assistant
Provides real-time navigation assistance for visually impaired users:
- Voice-guided turn-by-turn directions with distance and cardinal orientation
- Initial voice announcement of direction and bearing to destination
- Real-time updates on remaining distance and direction
- Search for destinations by voice input
- Nearby points of interest search (hospitals, bus stops, etc.)
- Automatic rerouting and progress tracking
- Fully accessible interface with voice feedback
- Works with Google Maps APIs or in simplified mode without internet

### 5. AI Assistant
An intelligent conversational assistant that can:
- Answer questions about the user's environment
- Provide contextual help with other app features
- Offer general assistance for visually impaired users
- Uses a completely free on-device solution (no paid APIs required)

## Setup

### Prerequisites
- Flutter SDK (latest stable version recommended)
- Android Studio or Visual Studio Code with Flutter extensions
- An Android or iOS device/emulator for testing
- Optional: Google Maps API key for enhanced navigation features

### Installation
1. Clone the repository:
   ```
   git clone https://github.com/OrangeRalph/vision_assist.git
   ```

2. Navigate to the project directory:
   ```
   cd vision_assist
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the app:
   ```
   flutter run
   ```

## Usage

### Object Detection
- Launch the app and select "Object Detection"
- Point your camera at objects
- The app will identify objects and speak their names
- Tap the screen to capture and analyze objects in more detail

### Text Recognition
- Launch the app and select "Text Recognition"
- Point your camera at text or select an image from your gallery
- Tap the "Capture & Recognize" button
- The app will extract text and display it on screen
- Use the "Read Text" button to have the text read aloud
- Use the "Copy" button to copy text to clipboard
- Use the "Share" button to share text with other apps

### Color Detection
- Launch the app and select "Color Detection"
- Point your camera at colored objects
- The app will identify dominant colors and speak their names
- Tap the screen to capture and analyze colors in more detail

### Navigation Assistant
- Launch the app and select "Navigation Assistant"
- Use the microphone button to speak your destination
- The app will find the location and generate a route
- Listen to the initial direction and distance announcement
- Follow turn-by-turn voice instructions as you walk
- Receive regular updates on your remaining distance and direction
- Use bottom buttons to find nearby hospitals or bus stops
- Tap "My Location" to recenter the map on your current position
- Tap "Stop" to end navigation

### AI Assistant
- Launch the app and select "AI Assistant"
- Type a question or tap the microphone for voice input
- The assistant will respond to your queries using our free on-device AI solution
- All processing happens locally on your device - no API keys or internet connection required

## Accessibility

Vision Assist is specifically designed with accessibility in mind:
- High contrast interface
- Large touch targets
- Text-to-speech feedback
- Simple, intuitive navigation
- Compatibility with screen readers
- Voice-controlled features throughout the app

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google ML Kit for text recognition capabilities
- Google Maps Platform for navigation services
- Google Cloud Speech-to-Text for voice recognition
- Flutter TTS for text-to-speech capabilities
- The Flutter team for the wonderful framework
