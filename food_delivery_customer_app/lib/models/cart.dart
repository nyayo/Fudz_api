import 'dart:convert' as convert;

import 'package:food_delivery_customer_app/models/menu_item.dart';

// In cart.dart (models), update the Cart and CartItem fromJson methods
class Cart {
  final String id;
  final List<CartItem> items;
  final double totalPrice;
  final int? restaurantId;
  final DateTime? createdAt;

  Cart({
    required this.id,
    required this.items,
    required this.totalPrice,
    this.restaurantId,
    this.createdAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id']?.toString() ?? '', // Convert to string
      items: (json['items'] as List? ?? [])
          .map((item) => CartItem.fromJson(item))
          .toList(),
      totalPrice:
          double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      restaurantId: json['restaurant_id'] is int ? json['restaurant_id'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
  Cart copyWith({
    String? id,
    List<CartItem>? items,
    double? totalPrice,
    int? restaurantId,
    DateTime? createdAt,
  }) {
    return Cart(
      id: id ?? this.id,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      restaurantId: restaurantId ?? this.restaurantId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'total_price': totalPrice,
      'restaurant_id': restaurantId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class CartItem {
  final String id;
  final MenuItem menuItem;
  final int quantity;
  final double totalPrice;
  final double
  unitPrice; // Price per unit at time of adding to cart (locked in)

  CartItem({
    required this.id,
    required this.menuItem,
    required this.quantity,
    required this.totalPrice,
    required this.unitPrice,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final menuItem = MenuItem.fromJson(json['menu_item'] ?? {});
    final unitPrice =
        double.tryParse(json['unit_price']?.toString() ?? '0') ??
        menuItem
            .discountedPrice; // Fallback to discounted price if not provided

    return CartItem(
      id: json['id']?.toString() ?? '', // Convert to string
      menuItem: menuItem,
      quantity:
          (json['qty'] is int
              ? json['qty']
              : int.tryParse(json['qty']?.toString() ?? '1')) ??
          1,
      totalPrice:
          double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item': menuItem.toJson(), // Use full MenuItem.toJson() to preserve all fields
      'qty': quantity,
      'total_price': totalPrice,
      'unit_price': unitPrice,
    };
  }
}

class Order {
  final int id;
  final String status;
  final String paymentStatus;
  final List<OrderItem> items;
  final double totalAmount;
  final DateTime placedAt;
  final String? deliveryAddress;
  final String? specialInstructions;
  final String? paymentMethod;
  final String? cancellationReason;
  final DateTime? deliveredAt;
  final DateTime? estimatedDelivery;
  final String? trackingNumber;
  final Map<String, dynamic>? dropoffLocation;
  final int? restaurantId;
  final String? restaurantName;
  final int? rating; // Order rating (1-5 stars)
  final String? ratingComment; // Optional comment for the rating

  Order({
    required this.id,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.totalAmount,
    required this.placedAt,
    this.deliveryAddress,
    this.specialInstructions,
    this.paymentMethod,
    this.cancellationReason,
    this.deliveredAt,
    this.estimatedDelivery,
    this.trackingNumber,
    this.dropoffLocation,
    this.restaurantId,
    this.restaurantName,
    this.rating,
    this.ratingComment,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    print('🛒 Creating Order from JSON: ${json.keys}');

    // Calculate total amount from items
    double totalAmount = 0.0;
    final items = (json['items'] as List? ?? []).map((item) {
      final orderItem = OrderItem.fromJson(item);
      totalAmount += orderItem.unitPrice * orderItem.quantity;
      return orderItem;
    }).toList();

    // If total_amount or totalAmount is provided, use it, otherwise calculate
    // Support both snake_case (API) and camelCase (local storage) formats
    if (json['total_amount'] != null || json['totalAmount'] != null) {
      totalAmount = double.tryParse(
        (json['total_amount'] ?? json['totalAmount']).toString()
      ) ?? totalAmount;
    }

    // Get restaurant information
    int? restaurantId;
    String? restaurantName;

    if (json['restaurant'] is int) {
      restaurantId = json['restaurant'];
    } else if (json['restaurant'] is Map) {
      final restaurantData = json['restaurant'] as Map;
      restaurantId = restaurantData['id'] is int ? restaurantData['id'] : null;
      restaurantName =
          restaurantData['restaurant_name']?.toString() ??
          restaurantData['name']?.toString();
    }
    
    // Fallback to restaurantId/restaurantName from local storage format
    restaurantId ??= json['restaurantId'] is int ? json['restaurantId'] : null;
    restaurantName ??= json['restaurantName']?.toString();

    // Handle dropoff_location or dropoffLocation - could be a Map, JSON string, or EWKT
    Map<String, dynamic>? dropoffLocation;
    final dropoffData = json['dropoff_location'] ?? json['dropoffLocation'];
    if (dropoffData is Map) {
      dropoffLocation = Map<String, dynamic>.from(dropoffData);
    } else if (dropoffData is String) {
      // Try EWKT format first: SRID=4326;POINT (lng lat)
      final ewktMatch = RegExp(r'POINT\s*\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(dropoffData);
      if (ewktMatch != null) {
        final lng = double.tryParse(ewktMatch.group(1) ?? '');
        final lat = double.tryParse(ewktMatch.group(2) ?? '');
        if (lng != null && lat != null) {
          dropoffLocation = {
            'type': 'Point',
            'coordinates': [lng, lat],
            'longitude': lng,
            'latitude': lat,
          };
          print('📍 Parsed EWKT dropoff_location: lat=$lat, lng=$lng');
        }
      } else {
        // Fallback: try JSON
        try {
          dropoffLocation = Map<String, dynamic>.from(
            convert.jsonDecode(dropoffData),
          );
        } catch (e) {
          print('⚠️ Could not parse dropoff_location: $dropoffData');
        }
      }
    }

    // Parse dates - support both snake_case (API) and camelCase (local storage) formats
    DateTime placedAt;
    final placedAtStr = json['placed_at']?.toString() ?? json['placedAt']?.toString();
    if (placedAtStr != null) {
      placedAt = DateTime.tryParse(placedAtStr) ?? DateTime.now();
    } else {
      placedAt = DateTime.now();
    }

    final deliveredAtStr = json['delivered_at']?.toString() ?? json['deliveredAt']?.toString();
    final estimatedDeliveryStr = json['estimated_delivery']?.toString() ?? json['estimatedDelivery']?.toString();

    return Order(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      // Support both snake_case (API) and camelCase (local storage) for all fields
      paymentStatus: (json['payment_status'] ?? json['paymentStatus'])?.toString() ?? 'pending',
      items: items,
      totalAmount: totalAmount,
      placedAt: placedAt,
      deliveryAddress: (json['delivery_address'] ?? json['deliveryAddress'])?.toString(),
      specialInstructions: (json['special_instructions'] ?? json['specialInstructions'])?.toString(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'])?.toString(),
      cancellationReason: (json['cancellation_reason'] ?? json['cancellationReason'])?.toString(),
      deliveredAt: deliveredAtStr != null ? DateTime.tryParse(deliveredAtStr) : null,
      estimatedDelivery: estimatedDeliveryStr != null ? DateTime.tryParse(estimatedDeliveryStr) : null,
      trackingNumber: (json['tracking_number'] ?? json['trackingNumber'])?.toString(),
      dropoffLocation: dropoffLocation,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      rating: json['rating'] is int ? json['rating'] : (json['rating'] != null ? int.tryParse(json['rating'].toString()) : null),
      ratingComment: (json['rating_comment'] ?? json['ratingComment'])?.toString(),
    );
  }

  // Add the toJson method for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'paymentStatus': paymentStatus,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'placedAt': placedAt.toIso8601String(),
      'deliveryAddress': deliveryAddress,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod,
      'cancellationReason': cancellationReason,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
      'trackingNumber': trackingNumber,
      'dropoffLocation': dropoffLocation,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'rating': rating,
      'ratingComment': ratingComment,
    };
  }

  // Add the copyWith method here
  Order copyWith({
    int? id,
    String? status,
    String? paymentStatus,
    List<OrderItem>? items,
    double? totalAmount,
    DateTime? placedAt,
    String? deliveryAddress,
    String? specialInstructions,
    String? paymentMethod,
    String? cancellationReason,
    DateTime? deliveredAt,
    DateTime? estimatedDelivery,
    String? trackingNumber,
    Map<String, dynamic>? dropoffLocation,
    int? restaurantId,
    String? restaurantName,
    int? rating,
    String? ratingComment,
  }) {
    return Order(
      id: id ?? this.id,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      placedAt: placedAt ?? this.placedAt,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }

  // Helper method to get the delivery address from dropoff location
  String get displayDeliveryAddress {
    // First try dropoff_location address
    if (dropoffLocation != null && dropoffLocation!['address'] != null) {
      return dropoffLocation!['address'].toString();
    }
    // Fallback to delivery_address field
    if (deliveryAddress != null && deliveryAddress!.isNotEmpty) {
      return deliveryAddress!;
    }
    // Final fallback
    return 'Delivery address not specified';
  }

  // Helper method to get coordinates from dropoff location
  Map<String, double>? get deliveryCoordinates {
    if (dropoffLocation != null) {
      final lat = dropoffLocation!['latitude'];
      final lng = dropoffLocation!['longitude'];

      if (lat != null && lng != null) {
        return {
          'latitude': lat is double
              ? lat
              : double.tryParse(lat.toString()) ?? 0.0,
          'longitude': lng is double
              ? lng
              : double.tryParse(lng.toString()) ?? 0.0,
        };
      }
    }
    return null;
  }

  // Helper methods
  bool get canBeCancelled =>
      ['pending', 'accepted'].contains(status.toLowerCase());

  bool get isDelivered =>
      status.toLowerCase() == 'delivered' ||
      status.toLowerCase() == 'completed';

  bool get canBeRated =>
      isDelivered &&
      deliveredAt != null &&
      deliveredAt!.isAfter(DateTime.now().subtract(const Duration(days: 7)));

  Duration get deliveryDuration {
    if (deliveredAt != null) {
      return deliveredAt!.difference(placedAt);
    }
    return const Duration();
  }

  String get formattedOrderNumber => '#${id.toString().padLeft(6, '0')}';
}

class OrderItem {
  final int id;
  final MenuItem menuItem;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.id,
    required this.menuItem,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    print('🛒 Creating OrderItem from JSON: ${json.keys}');
    
    final menuItemData = json['menu_item'] ?? {};
    print('🛒 OrderItem menu_item data: $menuItemData');
    print('🛒 OrderItem menu_item images: ${menuItemData['images']}');

    return OrderItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      menuItem: MenuItem.fromJson(json['menu_item'] ?? {}),
      quantity: json['qty'] is int
          ? json['qty']
          : int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
    );
  }

  // Add toJson method for OrderItem as well
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item': menuItem.toJson(),
      'qty': quantity,
      'unit_price': unitPrice,
    };
  }
}
