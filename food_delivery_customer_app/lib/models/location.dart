// models/location.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryLocation {
  final double latitude;
  final double longitude;
  String? address;
  final String? placeName;
  String? street;
  String? neighborhood;
  String? city;
  String? state;
  String? country;

  DeliveryLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
    this.street,
    this.neighborhood,
    this.city,
    this.state,
    this.country,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  String get shortAddress {
    if (street != null && street!.isNotEmpty) {
      return street!;
    }
    if (neighborhood != null && neighborhood!.isNotEmpty) {
      return neighborhood!;
    }
    if (placeName != null && placeName!.isNotEmpty) {
      return placeName!;
    }
    if (address != null && address!.isNotEmpty) {
      final parts = address!.split(',');
      return parts.isNotEmpty ? parts.first.trim() : address!;
    }
    return 'Unknown location';
  }

  String get fullAddress {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (neighborhood != null && neighborhood!.isNotEmpty) parts.add(neighborhood!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (parts.isEmpty) return shortAddress;
    return parts.join(', ');
  }

  String get detailedAddress {
    final parts = <String>[];
    if (neighborhood != null && neighborhood!.isNotEmpty) {
      parts.add(neighborhood!);
    }
    if (city != null && city!.isNotEmpty) {
      parts.add(city!);
    }
    return parts.isEmpty ? fullAddress : parts.join(', ');
  }

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      address: json['address'] as String?,
      placeName: json['place_name'] as String?,
      street: json['street'] as String?,
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'place_name': placeName,
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'country': country,
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
  final List<LatLng> polylinePoints;

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