import 'package:food_delivery_customer_app/models/promo.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:food_delivery_customer_app/utils/url_utils.dart';
import 'package:get_storage/get_storage.dart';

class MenuItemImage {
  final String imageUrl;

  MenuItemImage({required this.imageUrl});

  factory MenuItemImage.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return MenuItemImage(imageUrl: UrlUtils.ensureAbsoluteUrl(json['image']?.toString()) ?? '');
    } else if (json is String) {
      return MenuItemImage(imageUrl: UrlUtils.ensureAbsoluteUrl(json) ?? '');
    }
    return MenuItemImage(imageUrl: '');
  }
}

class MenuItem {
  final int id;
  final String title;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int category;
  final String? dietaryInfo;
  final int? prepTimeMinutes;
  final String? allergens;
  final String? categoryName;
  final String? restaurantName;
  final int? restaurantId;
  final List<MenuItemImage> images;
  final List<Promotion> promotions; // Add this line

  MenuItem({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.category,
    this.dietaryInfo,
    this.prepTimeMinutes,
    this.allergens,
    this.categoryName,
    this.restaurantName,
    this.restaurantId,
    required this.images,
    required this.promotions, // Add this line
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Handle restaurant information - more robust parsing
    String? restaurantName;
    int? restaurantId;

    // First, try to get restaurant_name directly from the JSON
    if (json['restaurant_name'] != null) {
      restaurantName = json['restaurant_name']?.toString();
      print('🏪 Restaurant name from direct field: $restaurantName');
    }

    // Handle restaurant field
    if (json['restaurant'] is int) {
      restaurantId = json['restaurant'];
      print('🏪 Restaurant ID: $restaurantId');
    } else if (json['restaurant'] is Map) {
      final restaurantObj = json['restaurant'] as Map;
      // Only override restaurantName if we didn't get it from direct field
      restaurantName ??= restaurantObj['restaurant_name']?.toString() ??
          restaurantObj['name']?.toString();
      restaurantId = _parseInt(restaurantObj['id']);
      print('🏪 Restaurant from Map: id=$restaurantId, name=$restaurantName');
    }

    // Fallback to restaurant_id field
    restaurantId ??= _parseInt(json['restaurant_id']);

    // Handle images array
    List<MenuItemImage> images = [];
    if (json['images'] is List) {
      images = (json['images'] as List).map((image) {
        return MenuItemImage.fromJson(image);
      }).toList();
    }

    // Handle promotions array
    List<Promotion> promotions = [];
    if (json['promotions'] is List) {
      promotions = (json['promotions'] as List).map((promo) {
        return Promotion.fromJson(promo);
      }).toList();
    }

    // Use first image as main image if available
    String? mainImageUrl;
    if (images.isNotEmpty) {
      mainImageUrl = images.first.imageUrl;
    } else {
      // Check for image URL in various formats:
      // - 'imageUrl' (from local storage via toJson)
      // - 'image_url' (from API)
      // - 'image' (alternative API format)
      // - 'image_link' (another possible format)
      // - 'photo' (another possible format)
      mainImageUrl = UrlUtils.ensureAbsoluteUrl(
        json['imageUrl']?.toString() ?? 
        json['image_url']?.toString() ?? 
        json['image']?.toString() ??
        json['image_link']?.toString() ??
        json['photo']?.toString()
      );
      
      // If still no image, try to look up from cached menu items
      if ((mainImageUrl == null || mainImageUrl.isEmpty) && json['id'] != null) {
        final menuItemId = _parseInt(json['id']);
        if (menuItemId != null) {
          mainImageUrl = _getCachedMenuItemImage(menuItemId);
        }
      }
    }

    return MenuItem(
      id: _parseInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Unknown Item',
      description: json['description']?.toString(),
      price: _parseDouble(json['price']) ?? 0.0,
      imageUrl: mainImageUrl,
      isAvailable: json['is_available'] ?? true,
      category: _parseInt(json['category']) ?? 0,
      dietaryInfo: json['dietary_info']?.toString(),
      prepTimeMinutes: _parseInt(json['prep_time_minutes']),
      allergens: json['allergens']?.toString(),
      categoryName: json['category_name']?.toString(),
      restaurantName: restaurantName,
      restaurantId: restaurantId,
      images: images,
      promotions: promotions, // Add this line
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'category': category,
      'dietary_info': dietaryInfo,
      'prep_time_minutes': prepTimeMinutes,
      'allergens': allergens,
      'category_name': categoryName,
      'restaurant_name': restaurantName,
      'restaurant_id': restaurantId,
      'images': images.map((img) => {'image': img.imageUrl}).toList(),
      'promotions': promotions.map((promo) => promo.toJson()).toList(),
    };
  }

  // Add getter for active promotions
  List<Promotion> get activePromotions {
    return promotions.where((promo) => promo.isCurrentlyActive).toList();
  }

  bool get hasActivePromotions => activePromotions.isNotEmpty;

  // Calculate discounted price
  double get discountedPrice {
    if (!hasActivePromotions) return price;

    // Use the highest discount from active promotions
    final highestDiscount = activePromotions
        .map((promo) => promo.discount)
        .reduce((a, b) => a > b ? a : b);

    return price * (1 - highestDiscount / 100);
  }

  String get formattedDiscountedPrice => CurrencyFormatter.format(discountedPrice);

  // Safe getters for null safety
  String get safeImageUrl => imageUrl ?? '';
  bool get hasImage => safeImageUrl.isNotEmpty;
  bool get hasDietaryInfo => (dietaryInfo ?? '').isNotEmpty;
  String get safeDietaryInfo => dietaryInfo ?? '';
  String get safeDescription => description ?? 'No description available';
  String get safeRestaurantName => restaurantName ?? 'Restaurant';

  String get formattedPrice => CurrencyFormatter.format(price);

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Look up a cached menu item image from GetStorage
  /// Uses the same cache key as MenuItemController
  static String? _getCachedMenuItemImage(int menuItemId) {
    try {
      final storage = GetStorage();
      final cachedData = storage.read('cached_menu_items');
      if (cachedData is Map) {
        final itemData = cachedData[menuItemId.toString()];
        if (itemData is Map) {
          // Try to get image from cached data in various formats
          final imageUrl = itemData['imageUrl']?.toString() ?? 
                          itemData['image_url']?.toString() ?? 
                          itemData['image']?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return UrlUtils.ensureAbsoluteUrl(imageUrl);
          }
          
          // Also check images array
          if (itemData['images'] is List && (itemData['images'] as List).isNotEmpty) {
            final firstImage = (itemData['images'] as List).first;
            if (firstImage is Map && firstImage['image'] != null) {
              return UrlUtils.ensureAbsoluteUrl(firstImage['image'].toString());
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error looking up cached menu item image: $e');
    }
    return null;
  }
}
