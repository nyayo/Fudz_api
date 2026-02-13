// services/location_service.dart
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import '../models/location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  
  static const String osmTileLayer = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  Future<DeliveryLocation?> getCurrentLocation() async {
    try {
      debugPrint('📍 Getting current location...');
      
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      debugPrint('📍 Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        debugPrint('📍 Requesting location service...');
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          debugPrint('❌ Location services are disabled');
          return null;
        }
      }

      // Check permission
      PermissionStatus permissionGranted = await _location.hasPermission();
      debugPrint('📍 Current permission status: $permissionGranted');
      
      if (permissionGranted == PermissionStatus.denied) {
        debugPrint('📍 Requesting location permission...');
        permissionGranted = await _location.requestPermission();
        debugPrint('📍 Permission after request: $permissionGranted');
        
        if (permissionGranted != PermissionStatus.granted &&
            permissionGranted != PermissionStatus.grantedLimited) {
          debugPrint('❌ Location permission denied');
          return null;
        }
      }

      if (permissionGranted == PermissionStatus.deniedForever) {
        debugPrint('❌ Location permission permanently denied');
        return null;
      }

      debugPrint('📍 Getting current position...');
      
      // Get current position with timeout
      LocationData locationData = await _location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('❌ Location timeout');
          throw Exception('Location request timed out');
        },
      );
      
      if (locationData.latitude == null || locationData.longitude == null) {
        debugPrint('❌ Could not obtain location coordinates');
        return null;
      }
      
      debugPrint('📍 Position obtained: ${locationData.latitude}, ${locationData.longitude}');
      debugPrint('📍 Accuracy: ${locationData.accuracy}m');

      // Get detailed address
      String address = 'Getting address...';
      try {
        address = await getDetailedAddress(
          locationData.latitude!, 
          locationData.longitude!
        );
        debugPrint('📍 Address obtained: $address');
      } catch (e) {
        debugPrint('⚠️ Error getting address: $e');
        address = '${locationData.latitude!.toStringAsFixed(6)}, ${locationData.longitude!.toStringAsFixed(6)}';
      }

      return DeliveryLocation(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        address: address,
      );
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
      return null;
    }
  }

  // Simplified address retrieval
  Future<String> getDetailedAddress(double lat, double lng) async {
    try {
      // Try geocoding package first
      String address = await getAddressFromGeocoding(lat, lng);
      if (address != 'Unknown Location') {
        return address;
      }

      // Fallback to coordinates
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    } catch (e) {
      debugPrint('Error getting detailed address: $e');
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
  }

  // Simplified geocoding
  Future<String> getAddressFromGeocoding(double lat, double lng) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isEmpty) {
        return 'Unknown Location';
      }
      
      final placemark = placemarks.first;
      List<String> addressParts = [];
      
      // Build address from available parts
      if (placemark.street != null && placemark.street!.isNotEmpty) {
        addressParts.add(placemark.street!);
      }
      if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
        addressParts.add(placemark.subLocality!);
      }
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        addressParts.add(placemark.locality!);
      }
      if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
        addressParts.add(placemark.administrativeArea!);
      }
      
      return addressParts.isNotEmpty ? addressParts.join(', ') : 'Unknown Location';
    } catch (e) {
      debugPrint('Error getting address from geocoding: $e');
      return 'Unknown Location';
    }
  }

  // Rest of your methods remain the same...
  Future<String> getAddressFromNominatim(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('$nominatimBaseUrl/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
        headers: {
          'User-Agent': 'FoodDeliveryApp/1.0',
        }
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        
        if (address.isEmpty) {
          return 'Unknown Location';
        }
        
        // Build a readable address
        List<String> addressParts = [];
        
        if (address['road'] != null) addressParts.add(address['road']);
        if (address['suburb'] != null) addressParts.add(address['suburb']);
        if (address['city'] != null) addressParts.add(address['city']);
        if (address['state'] != null) addressParts.add(address['state']);
        
        return addressParts.isNotEmpty ? addressParts.join(', ') : 'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      debugPrint('Error getting address from Nominatim: $e');
      return 'Unknown Location';
    }
  }

  Future<List<DeliveryLocation>> searchLocations(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$nominatimBaseUrl/search?format=json&q=$query&limit=5&addressdetails=1'),
        headers: {
          'User-Agent': 'FoodDeliveryApp/1.0',
        }
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

  double calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
    const double earthRadius = 6371000;
    double lat1 = point1.latitude * pi / 180;
    double lon1 = point1.longitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lon2 = point2.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  DeliveryRoute estimateRoute(DeliveryLocation pickup, DeliveryLocation dropoff) {
    final straightDistance = calculateDistance(pickup.latLng, dropoff.latLng);
    final estimatedRouteDistance = straightDistance * 1.3;
    const double averageSpeed = 25.0;
    final estimatedDuration = (estimatedRouteDistance / 1000) / averageSpeed * 3600;

    return DeliveryRoute(
      pickup: pickup,
      dropoff: dropoff,
      distance: estimatedRouteDistance,
      duration: estimatedDuration,
      polylinePoints: [pickup.latLng, dropoff.latLng],
    );
  }
}