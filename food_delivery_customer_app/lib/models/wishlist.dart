// models/wishlist.dart

import 'package:food_delivery_customer_app/models/menu_item.dart';

class Wishlist {
  final String id;
  final int userId;
  final List<WishlistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wishlist({
    required this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wishlist.fromJson(Map<String, dynamic> json) {
    print('🛍️ Creating Wishlist from JSON: $json');

    // Handle different response formats
    List<dynamic> itemsList = [];

    if (json['data'] is List) {
      // Response has 'data' field with list
      itemsList = List<dynamic>.from(json['data'] ?? []);
      print('🛍️ Found items in data field: ${itemsList.length}');
    } else if (json['results'] is List) {
      // Response has 'results' field
      itemsList = List<dynamic>.from(json['results'] ?? []);
      print('🛍️ Found items in results field: ${itemsList.length}');
    } else if (json['items'] is List) {
      // Response has 'items' field
      itemsList = List<dynamic>.from(json['items'] ?? []);
      print('🛍️ Found items in items field: ${itemsList.length}');
    } else if (json is List) {
      // Response is directly a list
      itemsList = (json as List).cast<dynamic>();
      print('🛍️ Response is direct list: ${itemsList.length}');
    }

    return Wishlist(
      id: json['id']?.toString() ?? '',
      userId: _parseInt(json['user_id']) ?? 0,
      items: itemsList.map((item) => WishlistItem.fromJson(item)).toList(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class WishlistItem {
  final String id;
  final int wishlistId;
  final MenuItem menuItem;
  final DateTime addedAt;

  WishlistItem({
    required this.id,
    required this.wishlistId,
    required this.menuItem,
    required this.addedAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    print('🛍️ Creating WishlistItem from JSON: $json');

    return WishlistItem(
      id: json['id']?.toString() ?? '',
      wishlistId: _parseInt(json['wishlist_id']) ?? 0,
      // Handle nested menu_item with images array
      menuItem: MenuItem.fromJson(json['menu_item'] ?? {}),
      addedAt: DateTime.parse(
        json['added_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wishlist_id': wishlistId,
      'menu_item': menuItem.toJson(),
      'added_at': addedAt.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
