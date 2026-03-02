import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

/// Global cache manager shared across the app.
/// Provides a 7-day stale period with up to 500 cached objects.
class AppCacheManager {
  AppCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'fudgoImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// Pre-cache a list of image URLs in the background.
  /// Safe to call from anywhere – errors are silently swallowed.
  static Future<void> preCacheImages(List<String?> urls) async {
    final validUrls = urls.where((u) => u != null && u.isNotEmpty).toList();
    // Process in batches of 6 to avoid flooding the network
    for (var i = 0; i < validUrls.length; i += 6) {
      final batch = validUrls.skip(i).take(6);
      try {
        await Future.wait(
          batch.map(
            (url) => instance.getSingleFile(url!).catchError((_) {
              // Swallow individual failures – other images can still be cached
              return Future<dynamic>.value(null);
            }).then((_) {}),
          ),
        );
      } catch (_) {
        // Swallow batch-level failures
      }
    }
  }
}

class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final IconData placeholderIcon;
  final bool showLoader;
  final bool useShimmer;
  final Color? placeholderColor;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholderIcon = Icons.image,
    this.showLoader = false,
    this.useShimmer = true,
    this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        cacheManager: AppCacheManager.instance,
        placeholder: (context, url) {
          if (showLoader) return _buildLoader();
          if (useShimmer) return _buildShimmer();
          return _buildPlaceholder(isSubtle: true);
        },
        errorWidget: (context, url, error) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeInCurve: Curves.easeOut,
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        maxWidthDiskCache: 800,
        maxHeightDiskCache: 800,
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: placeholderColor ?? Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool isSubtle = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isSubtle
            ? Colors.grey[50]
            : (placeholderColor ?? Colors.grey[200]),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          color: isSubtle ? Colors.grey[100] : Colors.grey[400],
          size: width != null ? (width! * 0.4).clamp(10.0, 40.0) : 40,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
