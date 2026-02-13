import 'package:food_delivery_customer_app/utils/url_utils.dart';

class RestaurantProfile {
  final int id;
  final String restaurantName;
  final String address;
  final String? businessLicense;
  final Map<String, dynamic>? openingHours;
  final double rating;
  final double? avgRating;
  final bool isApproved;
  final bool isActive;
  final int menuItemsCount;
  final int categoriesCount;
  final String? ownerName;
  final String? phone;
  final List<dynamic>? categories;
  final List<dynamic>? promotions;
  final String? imageUrl;
  final String? logoUrl;

  RestaurantProfile({
    required this.id,
    required this.restaurantName,
    required this.address,
    this.businessLicense,
    this.openingHours,
    required this.rating,
    this.avgRating,
    required this.isApproved,
    required this.isActive,
    required this.menuItemsCount,
    required this.categoriesCount,
    this.ownerName,
    this.phone,
    this.categories,
    this.promotions,
    this.imageUrl,
    this.logoUrl,
  });

  factory RestaurantProfile.fromJson(Map<String, dynamic> json) {
    return RestaurantProfile(
      id: json['id'] as int,
      restaurantName: json['restaurant_name'] as String,
      address: json['address'] as String,
      businessLicense: json['business_license'],
      openingHours: json['opening_hours'],
      rating: json['rating'] != null
          ? double.parse(json['rating'].toString())
          : 0.0,
      avgRating: json['avg_rating'] != null 
          ? double.parse(json['avg_rating'].toString())
          : null,
      isApproved: json['is_approved'] ?? false,
      isActive: json['is_active'] ?? true,
      menuItemsCount: json['menu_items_count'] ?? 0,
      categoriesCount: json['categories_count'] ?? 0,
      ownerName: json['owner_name'],
      phone: json['phone'],
      categories: json['categories'],
      promotions: json['promotions'],
      imageUrl: UrlUtils.ensureAbsoluteUrl(json['image']?.toString()),
      logoUrl: UrlUtils.ensureAbsoluteUrl(json['logo']?.toString() ?? json['logo_url']?.toString()),
    );
  }

  bool get isOpen => isActive && isApproved;
}