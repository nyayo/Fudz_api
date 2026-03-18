// services/location_service.dart
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import '../models/location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String osmTileLayer =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Get current location with high accuracy using Geolocator.
  /// Falls back to lower accuracy if high-accuracy fails.
  Future<DeliveryLocation?> getCurrentLocation() async {
    try {
      debugPrint('📍 Getting current location via Geolocator...');

      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Location services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled. Asking user to enable.');
        // On Android this opens the location settings; on iOS it throws
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('❌ User did not enable location services');
          return null;
        }
      }

      // 2. Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return null;
      }

      // 3. Try HIGH accuracy first with generous timeout
      Position? position;
      try {
        debugPrint('📍 Requesting HIGH accuracy position...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        ).timeout(const Duration(seconds: 20));
        debugPrint(
          '📍 HIGH accuracy position: ${position.latitude}, ${position.longitude} '
          '(accuracy: ${position.accuracy}m)',
        );
      } catch (e) {
        debugPrint('⚠️ High accuracy failed: $e — trying medium accuracy...');
      }

      // 4. Fall back to MEDIUM accuracy if high failed
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 15));
          debugPrint(
            '📍 MEDIUM accuracy position: ${position.latitude}, ${position.longitude} '
            '(accuracy: ${position.accuracy}m)',
          );
        } catch (e) {
          debugPrint('⚠️ Medium accuracy also failed: $e');
        }
      }

      // 5. Last resort: last known position
      if (position == null) {
        debugPrint('📍 Trying last known position...');
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          debugPrint(
            '📍 Last known position: ${position.latitude}, ${position.longitude}',
          );
        }
      }

      if (position == null) {
        debugPrint('❌ Could not obtain any position');
        return null;
      }

      // 6. If accuracy is very poor (> 500 m) try a second fix
      if (position.accuracy > 500) {
        debugPrint(
          '⚠️ Accuracy is ${position.accuracy}m — attempting a refinement...',
        );
        try {
          final refined = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 10));
          if (refined.accuracy < position.accuracy) {
            position = refined;
            debugPrint(
              '📍 Refined position: ${position.latitude}, ${position.longitude} '
              '(accuracy: ${position.accuracy}m)',
            );
          }
        } catch (_) {}
      }

      // Build address in the same call for reliability
      DeliveryLocation? location;
      try {
        location = await getDetailedAddress(
          position!.latitude,
          position!.longitude,
        );
        debugPrint('📍 Address: ${location.address}');
      } catch (e) {
        debugPrint('⚠️ Address lookup failed: $e');
        location = DeliveryLocation(
          latitude: position!.latitude,
          longitude: position!.longitude,
          address: '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}',
        );
      }

      return location;
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
      return null;
    }
  }

  // ── Address retrieval ──────────────────────────────────────────────

  Future<DeliveryLocation> getDetailedAddress(double lat, double lng) async {
    try {
      DeliveryLocation location = await _getAddressFromGeocoding(lat, lng);
      if (location.address != null && location.address != 'Unknown Location') {
        return location;
      }

      location = await getAddressFromNominatim(lat, lng);
      if (location.address != null && location.address != 'Unknown Location') {
        return location;
      }

      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
      );
    } catch (e) {
      debugPrint('Error getting detailed address: $e');
      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
      );
    }
  }

  Future<DeliveryLocation> _getAddressFromGeocoding(double lat, double lng) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return DeliveryLocation(
          latitude: lat,
          longitude: lng,
          address: 'Unknown Location',
        );
      }

      final placemark = placemarks.first;
      String? street = placemark.street;
      String? neighborhood = placemark.subLocality;
      String? city = placemark.locality ?? placemark.subAdministrativeArea;
      String? state = placemark.administrativeArea;
      String? country = placemark.country;

      final parts = <String>[];
      if (street != null && street.isNotEmpty) parts.add(street);
      if (neighborhood != null && neighborhood.isNotEmpty) parts.add(neighborhood);
      if (city != null && city.isNotEmpty) parts.add(city);
      if (state != null && state.isNotEmpty) parts.add(state);

      final address = parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';

      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: address,
        street: street,
        neighborhood: neighborhood,
        city: city,
        state: state,
        country: country,
      );
    } catch (e) {
      debugPrint('Error in geocoding: $e');
      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: 'Unknown Location',
      );
    }
  }

  Future<DeliveryLocation> getAddressFromNominatim(double lat, double lng) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$nominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
            ),
            headers: {'User-Agent': 'FoodDeliveryApp/1.0'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        if (address.isEmpty) {
          return DeliveryLocation(
            latitude: lat,
            longitude: lng,
            address: 'Unknown Location',
          );
        }

        String? street = address['road']?.toString();
        String? neighborhood = address['neighbourhood']?.toString() ?? 
                              address['suburb']?.toString() ??
                              address['quarter']?.toString();
        String? city = address['city']?.toString() ?? 
                       address['town']?.toString() ?? 
                       address['village']?.toString();
        String? state = address['state']?.toString();
        String? country = address['country']?.toString();

        final parts = <String>[];
        if (street != null && street.isNotEmpty) parts.add(street);
        if (neighborhood != null && neighborhood.isNotEmpty) parts.add(neighborhood);
        if (city != null && city.isNotEmpty) parts.add(city);
        if (state != null && state.isNotEmpty) parts.add(state);

        final displayAddress = parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';

        return DeliveryLocation(
          latitude: lat,
          longitude: lng,
          address: displayAddress,
          placeName: data['display_name'] ?? data['name'],
          street: street,
          neighborhood: neighborhood,
          city: city,
          state: state,
          country: country,
        );
      }
      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: 'Unknown Location',
      );
    } catch (e) {
      debugPrint('Error in Nominatim: $e');
      return DeliveryLocation(
        latitude: lat,
        longitude: lng,
        address: 'Unknown Location',
      );
    }
  }

  // ── Search ─────────────────────────────────────────────────────────

  Future<List<DeliveryLocation>> searchLocations(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$nominatimBaseUrl/search?format=json&q=$query&limit=5&addressdetails=1',
        ),
        headers: {'User-Agent': 'FoodDeliveryApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          return DeliveryLocation(
            latitude: double.parse(item['lat']),
            longitude: double.parse(item['lon']),
            address: item['display_name'] ?? 'Unknown',
            placeName: item['name'] ?? item['display_name'] ?? 'Unknown',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching locations: $e');
      return [];
    }
  }

  // ── Distance & routing ─────────────────────────────────────────────

  double calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
    const double earthRadius = 6371000;
    double lat1 = point1.latitude * pi / 180;
    double lon1 = point1.longitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lon2 = point2.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  DeliveryRoute estimateRoute(
    DeliveryLocation pickup,
    DeliveryLocation dropoff,
  ) {
    final straightDistance = calculateDistance(pickup.latLng, dropoff.latLng);
    final estimatedRouteDistance = straightDistance * 1.3;
    const double averageSpeed = 25.0;
    final estimatedDuration =
        (estimatedRouteDistance / 1000) / averageSpeed * 3600;

    return DeliveryRoute(
      pickup: pickup,
      dropoff: dropoff,
      distance: estimatedRouteDistance,
      duration: estimatedDuration,
      polylinePoints: [pickup.latLng, dropoff.latLng],
    );
  }
}
