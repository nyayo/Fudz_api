import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:get/get.dart';

import 'package:get_storage/get_storage.dart';

class MenuItemController extends GetxController {
  final ApiService _apiService = Get.find();
  final GetStorage _storage = GetStorage();

  final Rx<MenuItem?> selectedMenuItem = Rx<MenuItem?>(null);
  final RxBool isLoadingDetail = false.obs;
  final RxString error = ''.obs;

  // Cache for menu item details
  final RxMap<int, MenuItem> _menuItemCache = <int, MenuItem>{}.obs;
  final Map<int, DateTime> _menuItemCacheTimestamps = {};
  static const Duration _cacheDuration = Duration(
    minutes: 15,
  ); // Cache for 15 minutes

  // Keys for storage
  static const String _menuItemCacheKey = 'cached_menu_items';

  @override
  void onInit() {
    super.onInit();
    _loadCachedMenuItems();
  }

  /// Load cached menu items from storage
  void _loadCachedMenuItems() {
    try {
      final cachedData = _storage.read(_menuItemCacheKey);
      if (cachedData is Map) {
        for (final entry in cachedData.entries) {
          final itemId = int.tryParse(entry.key);
          final itemData = entry.value;
          if (itemId != null && itemData is Map) {
            try {
              _menuItemCache[itemId] = MenuItem.fromJson(
                Map<String, dynamic>.from(itemData),
              );
              _menuItemCacheTimestamps[itemId] = DateTime.now().subtract(
                Duration(minutes: 5),
              ); // Mark as somewhat stale
            } catch (e) {
              print('Error loading cached menu item $itemId: $e');
            }
          }
        }
        print(
          '✅ Loaded ${_menuItemCache.length} cached menu items from storage',
        );
      }
    } catch (e) {
      print('Error loading menu item cache: $e');
    }
  }

  /// Save menu items to storage
  Future<void> _saveMenuItemsToStorage() async {
    try {
      final Map<String, dynamic> cacheData = {};
      _menuItemCache.forEach((id, menuItem) {
        cacheData[id.toString()] = menuItem.toJson();
      });
      await _storage.write(_menuItemCacheKey, cacheData);
    } catch (e) {
      print('Error saving menu items to storage: $e');
    }
  }

  Future<void> getMenuItemDetail(
    int menuItemId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      final now = DateTime.now();
      final cachedTime = _menuItemCacheTimestamps[menuItemId];
      final isCacheValid =
          cachedTime != null && now.difference(cachedTime) < _cacheDuration;

      if (_menuItemCache.containsKey(menuItemId) &&
          isCacheValid &&
          !forceRefresh) {
        selectedMenuItem.value = _menuItemCache[menuItemId];
        print('✅ Using cached menu item details for ID: $menuItemId');
        return;
      }

      isLoadingDetail.value = true;
      error.value = '';

      final response = await _apiService.get('restaurants/items/$menuItemId/');
      if (response == null) {
        throw Exception('Failed to fetch menu item details');
      }

      final menuItem = MenuItem.fromJson(response);

      // Update cache
      _menuItemCache[menuItemId] = menuItem;
      _menuItemCacheTimestamps[menuItemId] = now;
      selectedMenuItem.value = menuItem;

      // Save to persistent storage
      await _saveMenuItemsToStorage();
    } catch (e) {
      error.value = e.toString();

      // Fallback to cache even if stale when API fails
      if (_menuItemCache.containsKey(menuItemId)) {
        selectedMenuItem.value = _menuItemCache[menuItemId];
        print('🔄 API failed, using cached menu item details');
      } else {
        rethrow;
      }
    } finally {
      isLoadingDetail.value = false;
    }
  }

  /// Preload multiple menu items in background
  Future<void> preloadMenuItems(List<int> menuItemIds) async {
    try {
      for (final itemId in menuItemIds) {
        if (!_menuItemCache.containsKey(itemId) || _isCacheStale(itemId)) {
          // Load in background without awaiting
          _apiService
              .get('restaurants/items/$itemId/')
              .then((response) {
                if (response != null) {
                  final menuItem = MenuItem.fromJson(response);
                  _menuItemCache[itemId] = menuItem;
                  _menuItemCacheTimestamps[itemId] = DateTime.now();
                  _saveMenuItemsToStorage();
                  print('✅ Preloaded menu item: ${menuItem.title}');
                }
              })
              .catchError((e) {
                print('❌ Failed to preload menu item $itemId: $e');
              });
        }
      }
    } catch (e) {
      print('Error preloading menu items: $e');
    }
  }

  /// Preload featured/popular menu items
  Future<void> preloadFeaturedMenuItems(List<MenuItem> featuredItems) async {
    final itemIds = featuredItems.map((item) => item.id).toList();
    await preloadMenuItems(itemIds);
  }

  /// Check if cache is stale for a menu item
  bool _isCacheStale(int menuItemId) {
    final cachedTime = _menuItemCacheTimestamps[menuItemId];
    if (cachedTime == null) return true;
    return DateTime.now().difference(cachedTime) > _cacheDuration;
  }

  /// Get menu item from cache (useful for quick access)
  MenuItem? getCachedMenuItem(int menuItemId) {
    if (_menuItemCache.containsKey(menuItemId) && !_isCacheStale(menuItemId)) {
      return _menuItemCache[menuItemId];
    }
    return null;
  }

  /// Clear cache methods
  void clearMenuItemCache() {
    _menuItemCache.clear();
    _menuItemCacheTimestamps.clear();
    _storage.remove(_menuItemCacheKey);
  }

  void clearStaleMenuItems() {
    final now = DateTime.now();
    final staleIds = _menuItemCacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .map((entry) => entry.key)
        .toList();

    for (final id in staleIds) {
      _menuItemCache.remove(id);
      _menuItemCacheTimestamps.remove(id);
    }

    _saveMenuItemsToStorage();
    print('🧹 Cleared ${staleIds.length} stale menu items from cache');
  }

  /// Force refresh a specific menu item
  Future<void> refreshMenuItem(int menuItemId) async {
    await getMenuItemDetail(menuItemId, forceRefresh: true);
  }

  // Getters for cache info
  int get cachedItemsCount => _menuItemCache.length;
  List<int> get cachedMenuItemIds => _menuItemCache.keys.toList();
}
