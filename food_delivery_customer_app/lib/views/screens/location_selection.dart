// views/screens/location/location_selection.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/services/location_service.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../controller/location_controller.dart';
import '../../../models/location.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final LocationController _locationController = Get.find<LocationController>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<DeliveryLocation> _searchResults = [];
  bool _isMapMoving = false;
  latlong2.LatLng? _lastMapCenter;

  @override
  void initState() {
    super.initState();
    
    // Listen to map movement
    _locationController.mapController.mapEventStream.listen((event) {
      if (event is MapEventMove && event.camera.center != _lastMapCenter) {
        _lastMapCenter = event.camera.center;
        if (!_isMapMoving) {
          _isMapMoving = true;
          _onMapMoved(event.camera.center);
        }
      }
    });

    // Center map on current location after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_locationController.currentLocation != null) {
        _locationController.mapController.move(
          _locationController.currentLocation!.latLng,
          15.0,
        );
      }
    });
  }

  // Handle map movement - update location when user stops moving map
  void _onMapMoved(latlong2.LatLng center) {
    // Debounce map movements
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_isMapMoving) {
        _isMapMoving = false;
        _updateLocationFromMap(center);
      }
    });
  }

  // Handle map tap
  void _onMapTap(TapPosition tapPosition, latlong2.LatLng point) async {
    await _updateLocationFromMap(point);
  }

  Future<void> _updateLocationFromMap(latlong2.LatLng point) async {
    try {
      // Show loading for the selected location
      final tempLocation = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: 'Getting address...',
      );
      _locationController.updateSelectedLocation(tempLocation);

      // Get address in background
      final address = await LocationService().getDetailedAddress(
        point.latitude, 
        point.longitude
      );
      
      final location = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: address,
      );
      
      _locationController.updateSelectedLocation(location);
    } catch (e) {
      print('❌ Error getting address for map point: $e');
      final location = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
      );
      _locationController.updateSelectedLocation(location);
    }
  }

  void _onSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _searchResults = [];
    });

    final results = await LocationService().searchLocations(_searchController.text.trim());
    setState(() {
      _searchResults = results;
    });
  }

  void _onSearchResultTap(DeliveryLocation location) {
    _locationController.updateSelectedLocation(location);
    _locationController.mapController.move(location.latLng, 15.0);
    setState(() {
      _searchResults = [];
      _searchFocusNode.unfocus();
    });
  }

  void _useCurrentLocation() async {
    await _locationController.initializeLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        actions: [
          Obx(() {
            final isGettingLocation = _locationController.isGettingLocationValue;
            return IconButton(
              icon: isGettingLocation 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              onPressed: isGettingLocation ? null : _useCurrentLocation,
            );
          }),
        ],
      ),
      body: Stack(
        children: [
          // Map
          Obx(() {
            return FlutterMap(
              mapController: _locationController.mapController,
              options: MapOptions(
                initialCenter: _locationController.currentLocation?.latLng ?? const latlong2.LatLng(0.3476, 32.5825),
                initialZoom: 13.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: LocationService.osmTileLayer,
                  userAgentPackageName: 'com.example.food_delivery',
                ),
                PolylineLayer(
                  polylines: _locationController.polylines,
                ),
                MarkerLayer(
                  markers: _locationController.markers,
                ),
              ],
            );
          }),

          // Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search for an address...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _onSearch(),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _searchResults = [];
                      });
                    }
                  },
                ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _searchResults.map((location) => ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                          location.placeName ?? location.address ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          location.address ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _onSearchResultTap(location),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // Center crosshair for precise location selection
          const Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.location_searching,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          ),

          // Location Details Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              final selectedLocation = _locationController.selectedLocation;
              final deliveryRoute = _locationController.deliveryRoute;
              final isGettingLocation = _locationController.isGettingLocationValue;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedLocation != null) ...[
                      Text(
                        'Delivery to:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isGettingLocation)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            )
                          else
                            const Icon(Icons.location_on, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedLocation.address ?? 'Getting address...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    if (deliveryRoute != null) ...[
                      Row(
                        children: [
                          Icon(Icons.directions, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text('${deliveryRoute.formattedDistance} • ${deliveryRoute.formattedDuration}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: (selectedLocation != null && !isGettingLocation) ? () {
                          Get.back(result: selectedLocation);
                        } : null,
                        child: const Text('Confirm Location', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}