import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vision_assist/services/google_maps_service.dart';
import 'package:vision_assist/services/google_speech_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  final GoogleMapsService _mapsService = GoogleMapsService();
  final GoogleSpeechService _speechService = GoogleSpeechService();
  final FlutterTts _flutterTts = FlutterTts();

  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final TextEditingController _destinationController = TextEditingController();

  // State variables
  bool _isLoading = true;
  bool _isNavigating = false;
  bool _isListening = false;
  String _feedbackText = 'Loading...';
  String _distanceText = '';
  String _durationText = '';
  bool _areGoogleApisAvailable = false;

  // Location data
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _navigationSteps = [];
  int _currentStepIndex = 0;

  // Timers for periodic location updates and navigation instructions
  Timer? _locationUpdateTimer;
  Timer? _navigationInstructionTimer;

  // Add counter for location updates
  int _locationUpdateCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _destinationController.dispose();
    _speechService.dispose();
    _locationUpdateTimer?.cancel();
    _navigationInstructionTimer?.cancel();
    _stopTts();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause navigation when app is in background
    if (state == AppLifecycleState.paused) {
      _locationUpdateTimer?.cancel();
      _navigationInstructionTimer?.cancel();
      _stopTts();
    } else if (state == AppLifecycleState.resumed && _isNavigating) {
      // Resume navigation when app is back in foreground
      _startLocationUpdates();
      _startNavigationInstructions();
    }
  }

  // Initialize all required services
  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    // Initialize text-to-speech
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(
      0.5,
    ); // Slower rate for clearer instructions
    await _flutterTts.setVolume(1.0);

    // Verify Google Maps API key is working
    _areGoogleApisAvailable = await _mapsService.verifyApiKey();
    if (!_areGoogleApisAvailable) {
      await _speak(
        'Google Maps APIs are not available. Some navigation features may be limited.',
      );
      debugPrint(
        'Google Maps APIs are not available, using limited functionality',
      );
    } else {
      debugPrint('Google Maps APIs are available, using full functionality');
    }

    // Initialize speech recognition
    bool speechAvailable = await _speechService.initialize();
    if (!speechAvailable) {
      await _speak('Speech recognition is not available on this device.');
    }

    // Request location permissions
    bool locationPermissionGranted = await _requestLocationPermission();
    if (!locationPermissionGranted) {
      return;
    }

    // Get current location
    bool locationObtained = await _getCurrentLocation();
    if (!locationObtained) {
      return;
    }

    setState(() => _isLoading = false);
    await _speak(
      'Navigation screen ready. Tap the mic button and say your destination.',
    );
  }

  // Request location permission
  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      await _speak('Location permission is required for navigation.');
      setState(() {
        _feedbackText = 'Location permission denied';
        _isLoading = false;
      });
      return false;
    }
    return true;
  }

  // Get current location
  Future<bool> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });

      if (_mapController.isCompleted) {
        try {
          final controller = await _mapController.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentLocation!, zoom: 16.0),
            ),
          );
        } catch (e) {
          debugPrint('Error animating camera: $e');
        }
      }
      return true;
    } catch (e) {
      await _speak(
        'Unable to get your current location. Please check your device settings.',
      );
      setState(() {
        _feedbackText = 'Location error: $e';
        _isLoading = false;
      });
      return false;
    }
  }

  // Update map markers
  void _updateMarkers() {
    Set<Marker> markers = {};

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: InfoWindow(title: _destinationController.text),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  // Search for destination and get directions
  Future<void> _searchAndNavigate(String query) async {
    if (query.isEmpty || _currentLocation == null) return;

    setState(() {
      _isLoading = true;
      _feedbackText = 'Searching for $query...';
    });

    try {
      // Convert address to coordinates
      List<Location> locations = [];

      try {
        locations = await locationFromAddress(query);
      } catch (e) {
        debugPrint('Error with locationFromAddress: $e');
        _speak(
          'Could not find the location. Please try again with a different address.',
        );
        setState(() {
          _isLoading = false;
          _feedbackText = 'Location not found';
        });
        return;
      }

      if (locations.isEmpty) {
        _speak(
          'Could not find the location. Please try again with a different address.',
        );
        setState(() {
          _isLoading = false;
          _feedbackText = 'Location not found';
        });
        return;
      }

      // Set destination
      _destinationLocation = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );

      // Update markers
      _updateMarkers();

      // Get directions
      await _getDirections();

      // Start navigation
      _startNavigation();
    } catch (e) {
      _speak(
        'An error occurred while searching for the destination. Please try again.',
      );
      setState(() {
        _isLoading = false;
        _feedbackText = 'Search error: $e';
      });
    }
  }

  // Get directions between current location and destination
  Future<void> _getDirections() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    setState(() {
      _isLoading = true;
      _feedbackText = 'Getting directions...';
    });

    try {
      if (_areGoogleApisAvailable) {
        // Use Google Directions API if available
        Map<String, dynamic> directions = await _mapsService.getDirections(
          origin: _currentLocation!,
          destination: _destinationLocation!,
          mode: 'walking', // Default to walking for blind users
        );

        if (directions['status'] != 'OK' &&
            directions['status'] != 'ZERO_RESULTS') {
          debugPrint('Directions API error: ${directions['status']}');
          // Fall back to simple straight line if API fails
          _createStraightLineRoute();
          return;
        }

        // Create polyline from API response
        List<PointLatLng> polylinePoints = directions['polylinePoints'];
        List<LatLng> polylineCoordinates = [];

        for (var point in polylinePoints) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              points: polylineCoordinates,
              width: 5,
            ),
          };

          _distanceText = directions['distance'];
          _durationText = directions['duration'];
          _navigationSteps = directions['steps'];
          _currentStepIndex = 0;
          _isLoading = false;
          _feedbackText = 'Route found';
        });

        // Zoom to show the entire route
        if (_mapController.isCompleted && polylineCoordinates.isNotEmpty) {
          try {
            final GoogleMapController controller = await _mapController.future;
            LatLngBounds bounds = _getBounds(polylineCoordinates);
            controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
          } catch (e) {
            debugPrint('Error animating camera to bounds: $e');
          }
        }

        // Announce route summary
        _speak(
          'Route found. Distance: ${directions['distance']}, estimated time: ${directions['duration']}. Starting navigation.',
        );
      } else {
        // Create simple route if Google Directions API is not available
        _createStraightLineRoute();
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
      // Fall back to simple straight line if there's an error
      _createStraightLineRoute();
    }
  }

  // Create a straight line route when Directions API is unavailable
  void _createStraightLineRoute() {
    if (_currentLocation == null || _destinationLocation == null) return;

    // Calculate approximate distance
    double distanceInMeters = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    // Calculate approximate walking time (assuming 1.4 m/s walking speed)
    double walkingTimeMinutes = distanceInMeters / (1.4 * 60);

    // Format distance and duration
    String distanceText =
        distanceInMeters >= 1000
            ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
            : '${distanceInMeters.round()} m';

    String durationText = '${walkingTimeMinutes.round()} min';

    List<LatLng> polylineCoordinates = [
      _currentLocation!,
      _destinationLocation!,
    ];

    // Create a simple step
    List<Map<String, dynamic>> simpleSteps = [
      {
        'html_instructions': 'Head toward your destination',
        'distance': {'text': distanceText},
        'duration': {'text': durationText},
        'end_location': {
          'lat': _destinationLocation!.latitude,
          'lng': _destinationLocation!.longitude,
        },
      },
    ];

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        ),
      };

      _distanceText = distanceText;
      _durationText = durationText;
      _navigationSteps = simpleSteps;
      _currentStepIndex = 0;
      _isLoading = false;
      _feedbackText = 'Basic route created';
    });

    // Zoom to show the entire route
    if (_mapController.isCompleted) {
      _mapController.future.then((controller) {
        try {
          LatLngBounds bounds = _getBounds(polylineCoordinates);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
        } catch (e) {
          debugPrint('Error animating camera to bounds: $e');
        }
      });
    }

    // Announce basic route info
    _speak(
      'Basic route created. Distance: $distanceText, estimated time: $durationText. Starting navigation.',
    );
  }

  // Calculate bounds for the route
  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (LatLng point in points) {
      if (minLat == null || point.latitude < minLat) {
        minLat = point.latitude;
      }
      if (maxLat == null || point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (minLng == null || point.longitude < minLng) {
        minLng = point.longitude;
      }
      if (maxLng == null || point.longitude > maxLng) {
        maxLng = point.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Start navigation mode
  void _startNavigation() {
    if (_navigationSteps.isEmpty) return;

    setState(() {
      _isNavigating = true;
    });

    // Get bearing to destination and speak initial direction
    _speakInitialDirectionAndDistance();

    // Speak the first instruction
    _speakNavigationInstruction(_navigationSteps[0]);

    // Start periodic location updates and navigation instructions
    _startLocationUpdates();
    _startNavigationInstructions();
  }

  // Calculate and speak the initial direction and distance
  void _speakInitialDirectionAndDistance() {
    if (_currentLocation == null || _destinationLocation == null) return;

    // Calculate bearing
    final bearing = _calculateBearing(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    // Convert bearing to cardinal direction
    final direction = _getDirectionFromBearing(bearing);

    // Calculate distance
    final distance =
        Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        ).round();

    // Format distance for speech
    String distanceText =
        distance >= 1000
            ? '${(distance / 1000).toStringAsFixed(1)} kilometers'
            : '$distance meters';

    // Speak the initial direction and distance
    _speak(
      'Your destination is $distanceText away to the $direction. $direction is at ${bearing.round()} degrees.',
    );
  }

  // Calculate bearing between two points
  double _calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    startLat = _toRadians(startLat);
    startLng = _toRadians(startLng);
    endLat = _toRadians(endLat);
    endLng = _toRadians(endLng);

    final y = math.sin(endLng - startLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(endLng - startLng);

    final bearingRadians = math.atan2(y, x);
    final bearingDegrees = _toDegrees(bearingRadians);
    return (bearingDegrees + 360) % 360; // Normalize to 0-360
  }

  // Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // Convert radians to degrees
  double _toDegrees(double radians) {
    return radians * (180.0 / math.pi);
  }

  // Get cardinal direction from bearing
  String _getDirectionFromBearing(double bearing) {
    const directions = [
      'north',
      'northeast',
      'east',
      'southeast',
      'south',
      'southwest',
      'west',
      'northwest',
      'north',
    ];
    return directions[(bearing / 45).round() % 8];
  }

  // Stop navigation mode
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _polylines = {};
      _navigationSteps = [];
      _currentStepIndex = 0;
      _distanceText = '';
      _durationText = '';
    });

    _locationUpdateTimer?.cancel();
    _navigationInstructionTimer?.cancel();
    _speak('Navigation stopped');
  }

  // Start periodic location updates
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _getCurrentLocation();
      _checkRouteProgress();
    });
  }

  // Start periodic navigation instructions
  void _startNavigationInstructions() {
    _navigationInstructionTimer?.cancel();
    _navigationInstructionTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) {
      if (_navigationSteps.isNotEmpty &&
          _currentStepIndex < _navigationSteps.length) {
        _speakNavigationInstruction(_navigationSteps[_currentStepIndex]);
      }
    });
  }

  // Check progress along the route
  void _checkRouteProgress() {
    if (!_isNavigating || _currentLocation == null || _navigationSteps.isEmpty)
      return;

    if (_currentStepIndex < _navigationSteps.length) {
      Map<String, dynamic> currentStep = _navigationSteps[_currentStepIndex];

      // Ensure we have end_location data
      if (currentStep['end_location'] == null) {
        debugPrint('Missing end_location data for current step');
        return;
      }

      LatLng endLocation = LatLng(
        currentStep['end_location']['lat'],
        currentStep['end_location']['lng'],
      );

      // Calculate distance to the end of the current step
      double distanceInMeters = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        endLocation.latitude,
        endLocation.longitude,
      );

      // Calculate bearing to end location
      double bearing = _calculateBearing(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        endLocation.latitude,
        endLocation.longitude,
      );
      String direction = _getDirectionFromBearing(bearing);

      // Update the feedback text with current distance and direction
      setState(() {
        _feedbackText =
            '${distanceInMeters.round()} meters to go. Direction: $direction';
      });

      // Periodically announce remaining distance and direction
      if (_locationUpdateCount % 3 == 0) {
        // Every ~15 seconds (3 * 5 second timer)
        String distanceText =
            distanceInMeters >= 1000
                ? '${(distanceInMeters / 1000).toStringAsFixed(1)} kilometers'
                : '${distanceInMeters.round()} meters';

        _speak(
          '$distanceText remaining to your next turn. Continue heading $direction.',
        );
      }
      _locationUpdateCount++;

      // If within 20 meters of the end of the step, move to the next step
      if (distanceInMeters < 20 &&
          _currentStepIndex < _navigationSteps.length - 1) {
        setState(() {
          _currentStepIndex++;
          _locationUpdateCount = 0; // Reset counter for new step
        });

        _speakNavigationInstruction(_navigationSteps[_currentStepIndex]);
      }

      // Check if we've reached the destination
      if (_destinationLocation != null) {
        double distanceToDestination = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        );

        if (distanceToDestination < 20) {
          _speak('You have reached your destination.');
          _stopNavigation();
        }
      }
    }
  }

  // Speak navigation instruction
  void _speakNavigationInstruction(Map<String, dynamic> step) {
    String instruction =
        step['html_instructions'] ?? 'Continue to your destination';
    // Remove HTML tags from instruction
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), '');
    _speak(instruction);
  }

  // Text to speech helper
  Future<void> _speak(String text) async {
    await _stopTts(); // Stop any ongoing speech

    // Create a completer to track when speech is done
    Completer<void> completer = Completer<void>();

    // Set up completion callback
    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Set up error handler
    _flutterTts.setErrorHandler((error) {
      debugPrint('TTS Error: $error');
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    // Speak the text
    await _flutterTts.speak(text);

    // For very short phrases, add a small delay to ensure the speech starts
    if (text.split(' ').length <= 3) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Return the future that completes when speaking is done
    return completer.future;
  }

  // Stop TTS
  Future<void> _stopTts() async {
    await _flutterTts.stop();
  }

  // Start listening for voice commands
  void _startListening() async {
    setState(() {
      _isListening = true;
      _feedbackText = 'Listening...';
    });

    // Speak the prompt and wait for it to complete before starting to listen
    await _speak('Where would you like to go?');

    // Add a small pause before starting to listen
    await Future.delayed(const Duration(milliseconds: 300));

    _speechService.startListening(
      onResult: (text) {
        setState(() {
          _destinationController.text = text;
          _feedbackText = 'You said: $text';
        });

        if (text.isNotEmpty) {
          _speechService.stopListening();
          _searchAndNavigate(text);
        }
      },
    );
  }

  // Search for nearby places of interest
  Future<void> _searchNearbyPlaces(String type) async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoading = true;
      _feedbackText = 'Searching for nearby $type...';
    });

    if (!_areGoogleApisAvailable) {
      _speak('Sorry, the places search feature is currently unavailable.');
      setState(() {
        _isLoading = false;
        _feedbackText = 'Places API not available';
      });
      return;
    }

    try {
      List<Map<String, dynamic>> places = await _mapsService.searchNearbyPlaces(
        location: _currentLocation!,
        type: type,
        radius: 500, // Search within 500 meters
      );

      if (places.isEmpty) {
        _speak('No $type found nearby.');
        setState(() {
          _isLoading = false;
          _feedbackText = 'No $type found nearby';
        });
        return;
      }

      // Announce the number of places found
      _speak(
        'Found ${places.length} $type nearby. The closest one is ${places.first['name']}, about ${_calculateDistance(_currentLocation!, places.first['location'])} meters away.',
      );

      setState(() {
        _isLoading = false;
        _feedbackText = 'Found ${places.length} nearby $type';
      });

      // Show dialog with list of places
      _showPlacesDialog(places, type);
    } catch (e) {
      _speak('An error occurred while searching for nearby places.');
      setState(() {
        _isLoading = false;
        _feedbackText = 'Search error: $e';
      });
    }
  }

  // Calculate distance between two points
  int _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ).round();
  }

  // Show dialog with list of nearby places
  void _showPlacesDialog(List<Map<String, dynamic>> places, String type) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Nearby $type'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:
                    places.length > 5 ? 5 : places.length, // Limit to 5 places
                itemBuilder: (context, index) {
                  final place = places[index];
                  final distance = _calculateDistance(
                    _currentLocation!,
                    place['location'],
                  );

                  return ListTile(
                    title: Text(place['name']),
                    subtitle: Text('${place['vicinity']} • ${distance}m away'),
                    onTap: () {
                      Navigator.pop(context);
                      _destinationLocation = place['location'];
                      _destinationController.text = place['name'];
                      _updateMarkers();
                      _getDirections();
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Assistant'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Google Map
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                    debugPrint('Map controller completed');
                  } else {
                    debugPrint('Map controller was already completed');
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 16.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: _markers,
                polylines: _polylines,
                compassEnabled: true,
              ),

          // Search bar
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Where to?',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.grey,
                    ),
                    onPressed: _startListening,
                    tooltip: 'Voice Search',
                  ),
                ),
                onSubmitted: _searchAndNavigate,
              ),
            ),
          ),

          // API Status Indicator
          if (!_areGoogleApisAvailable)
            Positioned(
              top: 60,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Limited functionality: Google Maps APIs unavailable',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Feedback text
          Positioned(
            bottom: 120,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _feedbackText,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Navigation info panel
          if (_isNavigating)
            Positioned(
              bottom: 170,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To: ${_destinationController.text}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          'Distance: $_distanceText',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Time: $_durationText',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),

      // Bottom action buttons
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.my_location,
              label: 'My Location',
              onPressed: _getCurrentLocation,
            ),
            _buildActionButton(
              icon: Icons.local_hospital,
              label: 'Hospital',
              onPressed: () => _searchNearbyPlaces('hospital'),
            ),
            _buildActionButton(
              icon: Icons.bus_alert,
              label: 'Bus Stop',
              onPressed: () => _searchNearbyPlaces('bus_station'),
            ),
            _buildActionButton(
              icon: _isNavigating ? Icons.stop : Icons.navigation,
              label: _isNavigating ? 'Stop' : 'Start',
              onPressed:
                  _isNavigating
                      ? _stopNavigation
                      : () {
                        if (_destinationLocation != null) {
                          _getDirections();
                        } else {
                          _speak('Please enter a destination first');
                        }
                      },
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon), onPressed: onPressed, tooltip: label),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
