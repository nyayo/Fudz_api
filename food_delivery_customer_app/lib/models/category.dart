
class CategoryImage {
  final String imageUrl;

  CategoryImage({required this.imageUrl});

  factory CategoryImage.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      // Handle different possible field names from API
      return CategoryImage(
        imageUrl: json['image']?.toString() ?? 
                 json['image_url']?.toString() ?? 
                 json['imageUrl']?.toString() ?? 
                 json['url']?.toString() ?? '',
      );
    } else if (json is String) {
      return CategoryImage(imageUrl: json);
    }
    return CategoryImage(imageUrl: '');
  }

  Map<String, dynamic> toJson() => {
    'image': imageUrl, // Use 'image' as key for consistency with API
  };

  @override
  String toString() => 'CategoryImage(imageUrl: $imageUrl)';
}

class Category {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int? itemsCount;
  final List<CategoryImage>? images;
  final String? imageUrl;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.itemsCount = 0,
    required this.images,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
  // Parse images array
  List<CategoryImage>? parsedImages;
  
  // Try multiple possible field names for images
  final rawImages = json['category_image'] ?? 
                    json['images'] ?? 
                    json['category_images'] ??
                    (json['image'] is List ? json['image'] : null);
  
  if (rawImages is List) {
    parsedImages = rawImages.map((image) {
      return CategoryImage.fromJson(image);
    }).toList();
  } else if (json['image'] is String) {
    // If image is a direct string URL, create a single image
    parsedImages = [CategoryImage(imageUrl: json['image'] as String)];
  }

  return Category(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['image'] as String?, // keep for fallback
    isActive: json['is_active'] as bool? ?? true,
    itemsCount: json['items_count'] as int? ?? 0,
    images: parsedImages,
  );
}

  String? mapImageUrl() {
    // First try the images array
    if (images != null && images!.isNotEmpty) {
      final firstImage = images!.first;
      if (firstImage.imageUrl.isNotEmpty) {
        return firstImage.imageUrl;
      }
    }
    // Fallback to direct imageUrl
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    return null;
  }

  String get safeImageUrl => mapImageUrl() ?? '';
  bool get hasImage => safeImageUrl.isNotEmpty;

  String get itemsCountText => '$itemsCount items';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    if (imageUrl != null) 'image': imageUrl,
    'is_active': isActive,
    'items_count': itemsCount,
    if (images != null) 
      'images': images!.map((img) => img.toJson()).toList(),
    if (images != null)
      'category_image': images!.map((img) => img.toJson()).toList(),
  };

  @override
  String toString() => 'Category(id: $id, name: $name, imageUrl: ${mapImageUrl()})';
}