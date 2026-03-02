import 'dart:async';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:get/get.dart';

/// Runs in the background after app start to pre-cache images that
/// the user is likely to see (restaurant logos, menu item images, promos).
/// All work is fire-and-forget; failures are silently swallowed.
class ImagePreCacheService extends GetxService {
  Timer? _periodicTimer;

  @override
  void onInit() {
    super.onInit();
    // Kick off initial pre-cache after a short delay to avoid competing with
    // the critical startup path.
    Future.delayed(const Duration(seconds: 3), () {
      _preCacheCurrentImages();
    });

    // Re-sync every 10 minutes while the app is alive
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _preCacheCurrentImages();
    });
  }

  @override
  void onClose() {
    _periodicTimer?.cancel();
    super.onClose();
  }

  /// Collect all visible image URLs from loaded data and push them
  /// through the cache manager in the background.
  Future<void> _preCacheCurrentImages() async {
    try {
      if (!Get.isRegistered<RestaurantController>()) return;
      final rc = Get.find<RestaurantController>();

      final urls = <String?>[];

      // Restaurant logos/images
      for (final r in rc.restaurants) {
        urls.add(r.logoUrl);
        urls.add(r.imageUrl);
      }

      // Menu items
      for (final m in rc.menuItems) {
        urls.add(m.imageUrl);
      }

      // Featured items with promotions
      for (final f in rc.featuredItemsWithPromotions) {
        urls.add(f.imageUrl);
      }

      if (urls.isEmpty) return;

      await AppCacheManager.preCacheImages(urls);
      // ignore: empty_catches
    } catch (_) {}
  }

  /// Manually trigger a pre-cache pass (e.g. after a data refresh).
  void triggerPreCache() {
    _preCacheCurrentImages();
  }
}
