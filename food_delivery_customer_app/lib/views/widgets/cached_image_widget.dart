import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final IconData placeholderIcon;
  final bool showLoader;

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'customImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholderIcon = Icons.image,
    this.showLoader = false,
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
        cacheManager: _cacheManager,
        placeholder: (context, url) =>
            showLoader ? _buildLoader() : _buildPlaceholder(isSubtle: true),
        errorWidget: (context, url, error) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 100),
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        maxWidthDiskCache: 800,
        maxHeightDiskCache: 800,
      ),
    );
  }

  Widget _buildPlaceholder({bool isSubtle = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isSubtle ? Colors.grey[50] : Colors.grey[200],
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
