import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class GoogleMapsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String apiKey = 'AIzaSyBwPJM7s9ZwG7CYKltKygYGGvToPFM0_BA';

  final Dio _dio = Dio();

  // Initialize and verify API key is working
  Future<bool> verifyApiKey() async {
    try {
      // Try a simple Directions API request to verify the key works
      // This is more likely to work since you mentioned having access to the Directions API
      final response = await _dio.get(
        '$_baseUrl/directions/json',
        queryParameters: {
          'origin': '40.712776,-74.005974', // New York City coordinates
          'destination': '40.758896,-73.985130', // Times Square coordinates
          'mode': 'walking',
          'key': apiKey,
        },
      );

      debugPrint('Google Maps API verification status: ${response.statusCode}');
      debugPrint(
        'Google Maps API verification response: ${response.data['status']}',
      );

      // Also log the error message if available for debugging
      if (response.data['status'] != 'OK') {
        debugPrint(
          'API error message: ${response.data['error_message'] ?? 'No error message provided'}',
        );
      }

      return response.statusCode == 200 && response.data['status'] == 'OK';
    } catch (e) {
      debugPrint('Error verifying Google Maps API key: $e');
      return false;
    }
  }

  // Get directions between two points
  Future<Map<String, dynamic>> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'walking', // Default to walking for blind users
    String? language,
  }) async {
    try {
      debugPrint(
        'Getting directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}',
      );

      final response = await _dio.get(
        '$_baseUrl/directions/json',
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': mode,
          'language': language ?? 'en',
          'key': apiKey,
        },
      );

      debugPrint('Directions API response status: ${response.statusCode}');
      debugPrint(
        'Directions API response data status: ${response.data['status']}',
      );

      // Log full response for debugging if there's an issue
      if (response.data['status'] != 'OK') {
        debugPrint(
          'API error message: ${response.data['error_message'] ?? 'No error message provided'}',
        );
        debugPrint('Full response: ${response.data}');
      }

      if (response.statusCode == 200) {
        // Log error message if present
        if (response.data['status'] != 'OK') {
          debugPrint(
            'Directions API error: ${response.data['status']} - ${response.data['error_message'] ?? 'No error message'}',
          );
          return {
            'status': response.data['status'],
            'error': response.data['error_message'] ?? 'Unknown error',
            'polylinePoints': <PointLatLng>[],
            'distance': '0 km',
            'duration': '0 min',
            'steps': [],
          };
        }

        // Create polyline decoder
        final polylinePoints = PolylinePoints();

        // Extract points from the response
        List<PointLatLng> decodedPoints = [];
        if (response.data['routes'].isNotEmpty) {
          decodedPoints = polylinePoints.decodePolyline(
            response.data['routes'][0]['overview_polyline']['points'],
          );

          debugPrint(
            'Successfully decoded polyline with ${decodedPoints.length} points',
          );
        } else {
          debugPrint('No routes found in directions response');
        }

        return {
          'status': response.data['status'],
          'polylinePoints': decodedPoints,
          'distance':
              response.data['routes'].isNotEmpty
                  ? response.data['routes'][0]['legs'][0]['distance']['text']
                  : '0 km',
          'duration':
              response.data['routes'].isNotEmpty
                  ? response.data['routes'][0]['legs'][0]['duration']['text']
                  : '0 min',
          'steps':
              response.data['routes'].isNotEmpty
                  ? response.data['routes'][0]['legs'][0]['steps']
                  : [],
        };
      } else {
        debugPrint(
          'Directions API request failed with status: ${response.statusCode}',
        );
        return {
          'status': 'FAILED',
          'polylinePoints': <PointLatLng>[],
          'distance': '0 km',
          'duration': '0 min',
          'steps': [],
        };
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
      return {
        'status': 'ERROR',
        'error': e.toString(),
        'polylinePoints': <PointLatLng>[],
        'distance': '0 km',
        'duration': '0 min',
        'steps': [],
      };
    }
  }

  // Search nearby places
  Future<List<Map<String, dynamic>>> searchNearbyPlaces({
    required LatLng location,
    required String type,
    int radius = 1000,
    String? language,
  }) async {
    try {
      debugPrint(
        'Searching for places of type "$type" near ${location.latitude},${location.longitude}',
      );

      final response = await _dio.get(
        '$_baseUrl/place/nearbysearch/json',
        queryParameters: {
          'location': '${location.latitude},${location.longitude}',
          'radius': radius.toString(),
          'type': type,
          'language': language ?? 'en',
          'key': apiKey,
        },
      );

      debugPrint('Places API response status: ${response.statusCode}');
      debugPrint('Places API response data status: ${response.data['status']}');

      // Log full response data for debugging
      if (response.data['status'] != 'OK') {
        debugPrint(
          'API error message: ${response.data['error_message'] ?? 'No error message provided'}',
        );
        debugPrint('Full response: ${response.data}');
      }

      if (response.statusCode == 200) {
        if (response.data['status'] != 'OK' &&
            response.data['status'] != 'ZERO_RESULTS') {
          debugPrint(
            'Places API error: ${response.data['status']} - ${response.data['error_message'] ?? 'No error message'}',
          );
          return [];
        }

        final places = <Map<String, dynamic>>[];
        if (response.data['results'] != null) {
          for (final place in response.data['results']) {
            places.add({
              'name': place['name'],
              'vicinity': place['vicinity'],
              'location': LatLng(
                place['geometry']['location']['lat'],
                place['geometry']['location']['lng'],
              ),
              'placeId': place['place_id'],
              'types': place['types'],
            });
          }
        }

        debugPrint('Found ${places.length} places nearby');
        return places;
      }
      debugPrint(
        'Places API request failed with status: ${response.statusCode}',
      );
      return [];
    } catch (e) {
      debugPrint('Error searching nearby places: $e');
      return [];
    }
  }

  // Get place details
  Future<Map<String, dynamic>> getPlaceDetails({
    required String placeId,
    String? language,
  }) async {
    try {
      debugPrint('Getting details for place ID: $placeId');

      final response = await _dio.get(
        '$_baseUrl/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields':
              'name,formatted_address,geometry,formatted_phone_number,opening_hours,website',
          'language': language ?? 'en',
          'key': apiKey,
        },
      );

      debugPrint('Place Details API response status: ${response.statusCode}');
      debugPrint(
        'Place Details API response data status: ${response.data['status']}',
      );

      // Log full response for debugging
      if (response.data['status'] != 'OK') {
        debugPrint(
          'API error message: ${response.data['error_message'] ?? 'No error message provided'}',
        );
        debugPrint('Full response: ${response.data}');
      }

      if (response.statusCode == 200) {
        if (response.data['status'] != 'OK') {
          debugPrint(
            'Place Details API error: ${response.data['status']} - ${response.data['error_message'] ?? 'No error message'}',
          );
          return {};
        }

        final result = response.data['result'];
        return {
          'name': result['name'],
          'address': result['formatted_address'],
          'location': LatLng(
            result['geometry']['location']['lat'],
            result['geometry']['location']['lng'],
          ),
          'phone': result['formatted_phone_number'] ?? 'N/A',
          'website': result['website'] ?? 'N/A',
          'openNow':
              result['opening_hours'] != null
                  ? result['opening_hours']['open_now']
                  : null,
        };
      }
      debugPrint(
        'Place Details API request failed with status: ${response.statusCode}',
      );
      return {};
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return {};
    }
  }
}
