// models/location.dart
import 'package:latlong2/latlong.dart' as latlong2;

class DeliveryLocation {
  final double latitude;
  final double longitude;
  String? address;
  final String? placeName;

  DeliveryLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
  });

  // Convert to latlong2.LatLng for flutter_map
  latlong2.LatLng get latLng => latlong2.LatLng(latitude, longitude);

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      address: json['address'] as String?,
      placeName: json['place_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'place_name': placeName,
    };
  }

  @override
  String toString() {
    return 'DeliveryLocation(lat: $latitude, lng: $longitude, address: $address)';
  }
}

class DeliveryRoute {
  final DeliveryLocation pickup;
  final DeliveryLocation dropoff;
  final double distance; // in meters
  final double duration; // in seconds
  final List<latlong2.LatLng> polylinePoints;

  DeliveryRoute({
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.duration,
    required this.polylinePoints,
  });

  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    final minutes = (duration / 60).ceil();
    return '$minutes min';
  }
}