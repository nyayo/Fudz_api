// controller/location_controller.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/services/location_service.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/location.dart';

class LocationController extends GetxController {
  final LocationService _locationService = LocationService();

  final Rx<DeliveryLocation?> _currentLocation = Rx<DeliveryLocation?>(null);
  final Rx<DeliveryLocation?> _selectedLocation = Rx<DeliveryLocation?>(null);
  final Rx<DeliveryRoute?> _deliveryRoute = Rx<DeliveryRoute?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isGettingLocation =
      false.obs; // Separate loading for location acquisition
  final RxString error = ''.obs;
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;

  GoogleMapController? _mapController;
  final RxBool _isProgrammaticMove = false.obs;
  final RxBool _isInitialized = false.obs;

  DeliveryLocation? get currentLocation => _currentLocation.value;
  DeliveryLocation? get selectedLocation => _selectedLocation.value;
  DeliveryRoute? get deliveryRoute => _deliveryRoute.value;
  bool get isInitialized => _isInitialized.value;
  bool get isProgrammaticMove => _isProgrammaticMove.value;

  @override
  void onInit() {
    super.onInit();
    // Auto-initialize location when controller starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeLocation();
    });
  }

  // FAST location initialization - get coordinates first, address later
  Future<void> initializeLocation() async {
    if (isGettingLocation.value) return;

    try {
      isGettingLocation.value = true;
      error.value = '';

      print('📍 Getting current location quickly...');

      // Get coordinates quickly first
      final location = await _locationService.getCurrentLocation();

      if (location != null) {
        _currentLocation.value = location;
        _selectedLocation.value = location;
        _isInitialized.value = true;

        // Update markers immediately with coordinates
        _updateMarkers();

        // Move map to location immediately
        _moveToLocation(location.latLng);

        print(
          '📍 Location coordinates obtained: ${location.latitude}, ${location.longitude}',
        );

        // Get address in background (non-blocking)
        _getAddressInBackground(location);
      } else {
        error.value = 'Could not get current location';
        print('❌ Location initialization failed');
      }
    } catch (e) {
      error.value = 'Failed to get location: $e';
      print('❌ Location initialization failed: $e');
    } finally {
      isGettingLocation.value = false;
    }
  }

  // Get address in background without blocking UI
  void _getAddressInBackground(DeliveryLocation location) async {
    try {
      print('📍 Getting address in background...');
      final locationWithAddress = await _locationService.getDetailedAddress(
        location.latitude,
        location.longitude,
      );

      // Update location with address
      final updatedLocation = DeliveryLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        address: locationWithAddress.address ?? locationWithAddress.fullAddress,
        street: locationWithAddress.street,
        neighborhood: locationWithAddress.neighborhood,
        city: locationWithAddress.city,
      );

      _currentLocation.value = updatedLocation;
      if (_selectedLocation.value?.latitude == location.latitude &&
          _selectedLocation.value?.longitude == location.longitude) {
        _selectedLocation.value = updatedLocation;
      }

      print('✅ Address obtained: ${updatedLocation.address}');
    } catch (e) {
      print('⚠️ Background address fetch failed: $e');
    }
  }

  void _updateMarkers() {
    markers.clear();

    if (_currentLocation.value != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation.value!.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    if (_selectedLocation.value != null &&
        _selectedLocation.value != _currentLocation.value) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation.value!.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  void moveToLocation(LatLng point, {double zoom = 15.0}) {
    _moveToLocation(point, zoom: zoom);
  }

  void _moveToLocation(LatLng point, {double zoom = 15.0}) {
    try {
      _isProgrammaticMove.value = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, zoom),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        _isProgrammaticMove.value = false;
      });
      print('📍 Map moved to: $point');
    } catch (e) {
      print('⚠️ Could not move map: $e');
    }
  }

  Future<void> updateSelectedLocation(DeliveryLocation location) async {
    _selectedLocation.value = location;
    _updateMarkers();

    if (_currentLocation.value != null) {
      await calculateDeliveryRoute();
    }

    _moveToLocation(location.latLng);
  }

  Future<void> calculateDeliveryRoute() async {
    if (_currentLocation.value == null || _selectedLocation.value == null) {
      return;
    }

    try {
      isLoading.value = true;
      final route = await _locationService.getRoute(
            _currentLocation.value!,
            _selectedLocation.value!,
          ) ??
          _locationService.estimateRoute(
            _currentLocation.value!,
            _selectedLocation.value!,
          );

      _deliveryRoute.value = route;
      _updatePolyline(route.polylinePoints);
    } catch (e) {
      error.value = 'Failed to calculate route: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _updatePolyline(List<LatLng> points) {
    polylines.clear();
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue.withOpacity(0.7),
        width: 4,
      ),
    );
  }

  // Get current location from map (when user moves map)
  Future<DeliveryLocation?> getLocationFromMap(LatLng point) async {
    try {
      final address = await _locationService.getDetailedAddress(
        point.latitude,
        point.longitude,
      );

      return DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: address.address ?? address.fullAddress,
        street: address.street,
        neighborhood: address.neighborhood,
        city: address.city,
      );
    } catch (e) {
      print('❌ Error getting location from map: $e');
      return DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address:
            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
      );
    }
  }

  // Update location when map is moved
  Future<void> updateLocationFromMap(LatLng point) async {
    try {
      isGettingLocation.value = true;
      final location = await getLocationFromMap(point);
      if (location != null) {
        _selectedLocation.value = location;
        _updateMarkers();
      }
    } catch (e) {
      error.value = 'Failed to update location: $e';
    } finally {
      isGettingLocation.value = false;
    }
  }

  Future<void> searchLocation(String query) async {
    try {
      isLoading.value = true;
      error.value = '';

      final locations = await _locationService.searchLocations(query);
      if (locations.isNotEmpty) {
        await updateSelectedLocation(locations.first);
      } else {
        throw Exception('Location not found');
      }
    } catch (e) {
      error.value = 'Location not found: $e';
    } finally {
      isLoading.value = false;
    }
  }

  double calculateDeliveryFee() {
    if (deliveryRoute == null) return 5.0;

    double distanceKm = deliveryRoute!.distance / 1000;

    if (distanceKm <= 2) return 3.0;
    if (distanceKm <= 5) return 5.0;
    if (distanceKm <= 10) return 8.0;
    return 12.0;
  }

  String get estimatedDeliveryTime {
    if (deliveryRoute == null) return '25-35 min';

    int minutes = (deliveryRoute!.duration / 60).ceil();
    int bufferTime = 15;

    return '${minutes + bufferTime}-${minutes + bufferTime + 10} min';
  }

  void clearRoute() {
    _deliveryRoute.value = null;
    polylines.clear();
  }

  Future<void> refreshLocation() async {
    await initializeLocation();
  }

  bool get hasLocation => _currentLocation.value != null;
  bool get isGettingLocationValue => isGettingLocation.value;
}
