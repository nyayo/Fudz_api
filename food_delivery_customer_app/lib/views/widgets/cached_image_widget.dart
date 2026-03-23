import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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

  /// Clear all cached images. Useful when images fail to load due to
  /// stale / corrupted cache entries.
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();
      debugPrint('🗑️ Image cache cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing image cache: $e');
    }
  }

  /// Pre-cache a list of image URLs in the background.
  /// Safe to call from anywhere – errors are silently swallowed.
  static Future<void> preCacheImages(List<String?> urls) async {
    final validUrls = urls.where((u) => u != null && u.isNotEmpty).toList();
    // Process in batches of 6 to avoid flooding the network
    for (var i = 0; i < validUrls.length; i += 6) {
      final batch = validUrls.skip(i).take(6);
      try {
        await Future.wait(
          batch.map((url) async {
            try {
              await instance.getSingleFile(url!);
            } catch (_) {
              // Swallow individual failures
            }
          }),
        );
      } catch (_) {
        // Swallow batch-level failures
      }
    }
  }
}

/// A robust image widget that uses [CachedNetworkImage] with automatic
/// fallback to [Image.network] when the cache layer fails.
class CachedImage extends StatefulWidget {
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
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  bool _useFallback = false;

  @override
  void didUpdateWidget(covariant CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _useFallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: _useFallback ? _buildFallbackImage() : _buildCachedImage(),
    );
  }

  /// Primary strategy: CachedNetworkImage with disk + memory cache.
  Widget _buildCachedImage() {
    return CachedNetworkImage(
      key: ValueKey(widget.imageUrl),
      imageUrl: widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheManager: AppCacheManager.instance,
      useOldImageOnUrlChange: false,
      placeholder: (context, url) {
        if (widget.showLoader) return _buildLoader();
        if (widget.useShimmer) return _buildShimmer();
        return _buildPlaceholder(isSubtle: true);
      },
      errorWidget: (context, url, error) {
        debugPrint(
          '⚠️ CachedImage cache-load failed ($url): $error — trying Image.network fallback',
        );
        // Switch to fallback on next frame to avoid build-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _useFallback = true);
        });
        return _buildLoader();
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeInCurve: Curves.easeOut,
      memCacheWidth: widget.width != null && widget.width!.isFinite
          ? (widget.width! * 2).toInt()
          : null,
    );
  }

  /// Fallback strategy: plain [Image.network] which bypasses the cache
  /// manager entirely. On Android this uses the platform HTTP stack.
  Widget _buildFallbackImage() {
    return Image.network(
      key: ValueKey(widget.imageUrl),
      widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.width != null && widget.width!.isFinite
          ? (widget.width! * 2).toInt()
          : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child; // loaded
        if (widget.useShimmer) return _buildShimmer();
        return _buildLoader();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '❌ CachedImage fallback also failed (${widget.imageUrl}): $error',
        );
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: widget.placeholderColor ?? Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool isSubtle = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isSubtle
            ? Colors.grey[50]
            : (widget.placeholderColor ?? Colors.grey[200]),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Center(
        child: Icon(
          widget.placeholderIcon,
          color: isSubtle ? Colors.grey[100] : Colors.grey[400],
          size: widget.width != null
              ? (widget.width! * 0.4).clamp(10.0, 40.0)
              : 40,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Container(
      width: widget.width,
      height: widget.height,
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
