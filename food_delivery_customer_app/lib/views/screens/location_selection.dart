// views/screens/location/location_selection.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/services/location_service.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../controller/location_controller.dart';
import '../../../models/location.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen>
    with SingleTickerProviderStateMixin {
  final LocationController _locationController = Get.find<LocationController>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<DeliveryLocation> _searchResults = [];
  bool _isMapMoving = false;
  latlong2.LatLng? _lastMapCenter;
  bool _showSearchResults = false;
  
  // Bottom sheet animation
  late AnimationController _bottomSheetController;
  late Animation<Offset> _slideAnimation;
  final double _bottomSheetHeight = 280.0;
  
  // Recent locations (mock data for now)
  final List<DeliveryLocation> _recentLocations = [];

  @override
  void initState() {
    super.initState();
    
    _bottomSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeOut,
    ));
    _bottomSheetController.forward();

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

  @override
  void dispose() {
    _bottomSheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onMapMoved(latlong2.LatLng center) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_isMapMoving) {
        _isMapMoving = false;
        _updateLocationFromMap(center);
      }
    });
  }

  void _onMapTap(TapPosition tapPosition, latlong2.LatLng point) async {
    await _updateLocationFromMap(point);
  }

  Future<void> _updateLocationFromMap(latlong2.LatLng point) async {
    try {
      final tempLocation = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: 'Searching...',
      );
      _locationController.updateSelectedLocation(tempLocation);

      final address = await LocationService().getDetailedAddress(
        point.latitude,
        point.longitude,
      );

      final location = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: address.address ?? address.fullAddress,
        street: address.street,
        neighborhood: address.neighborhood,
        city: address.city,
        state: address.state,
        country: address.country,
      );

      _locationController.updateSelectedLocation(location);
    } catch (e) {
      final location = DeliveryLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        address: 'Location selected',
      );
      _locationController.updateSelectedLocation(location);
    }
  }

  void _onSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _showSearchResults = true;
      _searchResults = [];
    });

    final results = await LocationService().searchLocations(
      _searchController.text.trim(),
    );
    setState(() {
      _searchResults = results;
    });
  }

  void _onSearchResultTap(DeliveryLocation location) {
    _locationController.updateSelectedLocation(location);
    _locationController.mapController.move(location.latLng, 16.0);
    setState(() {
      _showSearchResults = false;
      _searchFocusNode.unfocus();
    });
    _searchController.clear();
  }

  void _useCurrentLocation() async {
    await _locationController.initializeLocation();
    if (_locationController.currentLocation != null) {
      _locationController.mapController.move(
        _locationController.currentLocation!.latLng,
        16.0,
      );
    }
  }

  void _closeSearch() {
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
    _searchFocusNode.unfocus();
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full Screen Map
          Obx(() {
            return FlutterMap(
              mapController: _locationController.mapController,
              options: MapOptions(
                initialCenter:
                    _locationController.currentLocation?.latLng ??
                    const latlong2.LatLng(0.3476, 32.5825),
                initialZoom: 15.0,
                onTap: _onMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: LocationService.osmTileLayer,
                  userAgentPackageName: 'com.example.food_delivery',
                ),
                // Current location accuracy circle
                if (_locationController.currentLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _locationController.currentLocation!.latLng,
                        radius: 30,
                        color: TColor.primary.withOpacity(0.1),
                        borderColor: TColor.primary.withOpacity(0.3),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _locationController.markers),
              ],
            );
          }),

          // Semi-transparent overlay when searching
          if (_showSearchResults)
            GestureDetector(
              onTap: _closeSearch,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          // Top Safe Area with Search
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // Top Bar
                    Row(
                      children: [
                        // Back Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Get.back(),
                            color: TColor.primaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Search Field
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Search location...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[400],
                                ),
                                suffixIcon: Obx(() {
                                  if (_locationController.isGettingLocationValue) {
                                    return Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: TColor.primaryText,
                              ),
                              onSubmitted: (_) => _onSearch(),
                              onTap: () {
                                setState(() {
                                  _showSearchResults = true;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Results Dropdown
          if (_showSearchResults && _searchResults.isNotEmpty)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final location = _searchResults[index];
                      return ListTile(
                        onTap: () => _onSearchResultTap(location),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: TColor.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: TColor.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          location.placeName ?? location.street ?? 'Location',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          location.fullAddress,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.north_west,
                          size: 16,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Center Pin (stays fixed while map moves)
          const Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _CenterPinWidget(),
              ),
            ),
          ),

          // Current Location FAB
          Positioned(
            right: 16,
            bottom: _bottomSheetHeight + 16,
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Obx(() {
                  final isGettingLocation =
                      _locationController.isGettingLocationValue;
                  return FloatingActionButton(
                    heroTag: 'currentLocation',
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    onPressed: isGettingLocation ? null : _useCurrentLocation,
                    child: isGettingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TColor.primary,
                            ),
                          )
                        : Icon(
                            Icons.my_location,
                            color: TColor.primary,
                          ),
                  );
                }),
              ),
            ),
          ),

          // Zoom Controls
          Positioned(
            right: 16,
            bottom: _bottomSheetHeight + 80,
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomButton(
                      icon: Icons.add,
                      onTap: () {
                        final currentZoom = _locationController.mapController.camera.zoom;
                        _locationController.mapController.move(
                          _locationController.mapController.camera.center,
                          currentZoom + 1,
                        );
                      },
                    ),
                    Container(
                      height: 1,
                      width: 30,
                      color: Colors.grey[200],
                    ),
                    _ZoomButton(
                      icon: Icons.remove,
                      onTap: () {
                        final currentZoom = _locationController.mapController.camera.zoom;
                        _locationController.mapController.move(
                          _locationController.mapController.camera.center,
                          currentZoom - 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBottomSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final selectedLocation = _locationController.selectedLocation;
          final isGettingLocation = _locationController.isGettingLocationValue;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Selected Location Card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Icon Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: TColor.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: TColor.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deliver to',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isGettingLocation)
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: TColor.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Finding address...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                )
                              else if (selectedLocation != null)
                                Text(
                                  selectedLocation.street ?? 
                                  selectedLocation.neighborhood ?? 
                                  selectedLocation.placeName ??
                                  selectedLocation.address ??
                                  'Unknown Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: TColor.primaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  'Select a location on the map',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Full Address
                    if (selectedLocation != null && !isGettingLocation) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedLocation.neighborhood != null)
                                    Text(
                                      selectedLocation.neighborhood!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  if (selectedLocation.city != null)
                                    Text(
                                      '${selectedLocation.city ?? ''}${selectedLocation.country != null ? ', ${selectedLocation.country}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedLocation != null && !isGettingLocation
                              ? TColor.primary
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: selectedLocation != null && !isGettingLocation
                            ? () {
                                // Add to recent locations
                                if (!_recentLocations.any((loc) =>
                                    loc.latitude == selectedLocation.latitude &&
                                    loc.longitude == selectedLocation.longitude)) {
                                  _recentLocations.insert(0, selectedLocation);
                                  if (_recentLocations.length > 5) {
                                    _recentLocations.removeLast();
                                  }
                                }
                                Get.back(result: selectedLocation);
                              }
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Confirm Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// Center Pin Widget with Animation
class _CenterPinWidget extends StatefulWidget {
  const _CenterPinWidget();

  @override
  State<_CenterPinWidget> createState() => _CenterPinWidgetState();
}

class _CenterPinWidgetState extends State<_CenterPinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: TColor.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: TColor.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// Zoom Button Widget
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: TColor.primary,
          size: 20,
        ),
      ),
    );
  }
}
