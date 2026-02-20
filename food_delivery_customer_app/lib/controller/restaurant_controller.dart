import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/controller/category_controller.dart';
import 'package:food_delivery_customer_app/controller/menu_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/restaurant.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/cache_service.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class RestaurantController extends GetxController {
  final ApiService _apiService = Get.find();
  final GetStorage _storage = GetStorage();

  final RxMap<int, RestaurantProfile> _restaurantCache =
      <int, RestaurantProfile>{}.obs;
  final RxMap<int, List<dynamic>> _restaurantCategoriesCache =
      <int, List<dynamic>>{}.obs;
  final Map<int, DateTime> _restaurantCacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10);
  final RxList<RestaurantProfile> restaurants = <RestaurantProfile>[].obs;
  final RxList<RestaurantProfile> popularRestaurants =
      <RestaurantProfile>[].obs;
  final RxList<MenuItem> menuItems = <MenuItem>[].obs;
  final RxList<MenuItem> allMenuItems = <MenuItem>[].obs;
  final RxList<MenuItem> restaurantMenuItems = <MenuItem>[].obs;
  final RxList<MenuItem> categoryMenuItems = <MenuItem>[].obs;
  final Rx<RestaurantProfile?> selectedRestaurant = Rx<RestaurantProfile?>(
    null,
  );
  final RxList<dynamic> categories = <dynamic>[].obs;

  // Smart loading - only shows on first launch or after fresh login
  final RxBool isInitialLoading = false.obs;

  // Background loading flags
  final RxBool isLoading = false.obs;
  final RxBool isLoadingDetails = false.obs;
  final RxBool isLoadingAllMenuItems = false.obs;
  final RxBool isLoadingRestaurantMenuItems = false.obs;
  final RxBool isLoadingCategoryMenuItems = false.obs;
  final RxBool isLoadingMenuItems = false.obs;
  final RxString error = ''.obs;

  // Pagination for Restaurants
  final RxInt currentRestaurantPage = 1.obs;
  final RxBool hasMoreRestaurants = true.obs;
  final RxBool isLoadingMoreRestaurants = false.obs;

  // Pagination for Menu Items
  final RxInt currentMenuItemsPage = 1.obs;
  final RxBool hasMoreMenuItems = true.obs;
  final RxBool isLoadingMoreMenuItems = false.obs;

  final RxList<MenuItem> featuredItemsWithPromotions = <MenuItem>[].obs;
  final RxBool isLoadingFeaturedItems = false.obs;

  // Keys for GetStorage
  static const String _hasLoadedDataKey = 'has_loaded_initial_data';
  static const String _userSessionKey = 'current_user_session';

  @override
  void onInit() {
    super.onInit();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // ── 1. Load from local cache INSTANTLY (synchronous) ──
    final hasCachedData = _loadFromCacheSync();

    // If no cache at all, show loading indicator
    if (!hasCachedData) {
      isInitialLoading.value = true;
    }

    // ── 2. Fire-and-forget: Sync from API in BACKGROUND (non-blocking) ──
    // This ensures UI loads instantly while data syncs in background
    _syncDataInBackground();
  }

  /// Load all data from local cache SYNCHRONOUSLY (instant).
  /// Returns true if any data was loaded.
  bool _loadFromCacheSync() {
    bool hasData = false;

    // Restaurants
    final cachedRestaurants = CacheService.getRestaurants();
    if (cachedRestaurants != null && cachedRestaurants.isNotEmpty) {
      final parsed = cachedRestaurants
          .map((json) => RestaurantProfile.fromJson(json))
          .toList();
      restaurants.value = parsed;
      popularRestaurants.value = parsed.take(5).toList();
      hasData = true;
      print('📦 Loaded ${parsed.length} restaurants from cache');
    }

    // Menu items
    final cachedMenuItems = CacheService.getMenuItems();
    if (cachedMenuItems != null && cachedMenuItems.isNotEmpty) {
      final parsed = cachedMenuItems
          .map((json) => MenuItem.fromJson(json))
          .toList();
      allMenuItems.value = parsed;
      menuItems.value = parsed;
      hasData = true;
      print('📦 Loaded ${parsed.length} menu items from cache');
    }

    // Featured items with promotions
    final cachedFeatured = CacheService.getFeaturedItems();
    if (cachedFeatured != null && cachedFeatured.isNotEmpty) {
      final parsed = cachedFeatured
          .map((json) => MenuItem.fromJson(json))
          .toList();
      featuredItemsWithPromotions.value = parsed;
      hasData = true;
      print('📦 Loaded ${parsed.length} featured items from cache');
    }

    return hasData;
  }

  /// Sync data from API in BACKGROUND (fire-and-forget, non-blocking)
  Future<void> _syncDataInBackground() async {
    try {
      // Run all syncs in parallel but don't await them
      // This ensures the splash screen loads instantly
      Future.wait([
        _syncRestaurants(),
        _syncMenuItems(),
        _syncFeaturedItems(),
      ]).then((_) {
        // Clear loading flag after background sync completes
        isInitialLoading.value = false;
        
        // Preload extra data after main sync completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          preloadPopularRestaurantsDetails();
          preloadPopularMenuItems();
          if (Get.isRegistered<CategoryController>()) {
            final categoryController = Get.find<CategoryController>();
            categoryController.preloadPopularCategories();
          }
        });
        _storage.write(_hasLoadedDataKey, true);
      }).catchError((e) {
        // Also clear loading flag on error so UI can show content
        isInitialLoading.value = false;
        print('❌ Background sync error: $e');
      });
    } catch (e) {
      // Clear loading flag on setup error
      isInitialLoading.value = false;
      print('❌ Background sync setup error: $e');
    }
  }

  /// Fetch restaurants from API and update cache + reactive lists.
  Future<void> _syncRestaurants() async {
    try {
      final response = await _apiService.get('restaurants/restaurants/');
      List<dynamic> restaurantsList = [];

      if (response is List) {
        restaurantsList = response;
      } else if (response is Map) {
        restaurantsList = response['results'] ?? response['data'] ?? [];
      }

      final newRestaurants = restaurantsList
          .map(
            (json) => RestaurantProfile.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      // Update reactive lists (Obx widgets rebuild automatically)
      restaurants.value = newRestaurants;
      popularRestaurants.value = newRestaurants.take(5).toList();

      // Persist to cache
      final jsonList = newRestaurants.map((r) => r.toJson()).toList();
      await CacheService.saveRestaurants(jsonList);
      print('✅ Synced ${newRestaurants.length} restaurants from API');
    } catch (e) {
      print('❌ Sync restaurants error: $e');
      // Cache was already loaded — UI still shows data
    }
  }

  /// Fetch menu items from API and update cache + reactive lists.
  Future<void> _syncMenuItems() async {
    try {
      final response = await _apiService.get('restaurants/items/');
      List<dynamic> menuItemsList = [];

      if (response is List) {
        menuItemsList = response;
      } else if (response is Map) {
        menuItemsList = response['results'] ?? response['data'] ?? [];
      }

      final newList = menuItemsList
          .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
          .toList();

      allMenuItems.value = newList;
      menuItems.value = newList;

      // Persist to cache
      final jsonList = newList.map((m) => m.toJson()).toList();
      await CacheService.saveMenuItems(jsonList);
      print('✅ Synced ${newList.length} menu items from API');
    } catch (e) {
      print('❌ Sync menu items error: $e');
    }
  }

  /// Fetch featured promo items from API and update cache + reactive lists.
  Future<void> _syncFeaturedItems() async {
    try {
      // Wait for menu items to be synced first if needed
      if (allMenuItems.isEmpty) {
        await _syncMenuItems();
      }

      final featuredItems = allMenuItems.where((item) {
        return item.hasActivePromotions && item.isAvailable;
      }).toList();

      featuredItemsWithPromotions.value = featuredItems;

      // Persist to cache
      final jsonList = featuredItems.map((m) => m.toJson()).toList();
      await CacheService.saveFeaturedItems(jsonList);
      print('✅ Synced ${featuredItems.length} featured promo items');
    } catch (e) {
      print('❌ Sync featured items error: $e');
    }
  }

  /// Call this after user logs in successfully
  Future<void> onUserLogin(String userId) async {
    final previousSession = _storage.read(_userSessionKey);

    if (previousSession != userId) {
      await _storage.write(_userSessionKey, userId);
      await _storage.write(_hasLoadedDataKey, false);
      await CacheService.clearAll();

      // Load fresh data with cache-first strategy
      isInitialLoading.value = true;
      try {
        await Future.wait([
          _syncRestaurants(),
          _syncMenuItems(),
          _syncFeaturedItems(),
        ]);
        await _storage.write(_hasLoadedDataKey, true);
      } finally {
        isInitialLoading.value = false;
      }
    }
  }

  /// Call this when user logs out
  Future<void> onUserLogout() async {
    await _storage.remove(_userSessionKey);
    await _storage.write(_hasLoadedDataKey, false);
    await CacheService.clearAll();

    restaurants.clear();
    popularRestaurants.clear();
    menuItems.clear();
    allMenuItems.clear();
    featuredItemsWithPromotions.clear();
  }

  Future<void> getFeaturedItemsWithPromotions({
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) isLoadingFeaturedItems.value = true;
      error.value = '';

      await getMenuItems(showLoading: false);

      final featuredItems = allMenuItems.where((item) {
        return item.hasActivePromotions && item.isAvailable;
      }).toList();

      featuredItemsWithPromotions.value = featuredItems;

      print('Found ${featuredItems.length} items with active promotions');
    } catch (e) {
      error.value = 'Error fetching featured items: $e';
      print('Error fetching featured items: $e');
    } finally {
      if (showLoading) isLoadingFeaturedItems.value = false;
    }
  }

  Future<void> getRestaurants({
    bool showLoading = false,
    bool loadMore = false,
  }) async {
    try {
      if (loadMore) {
        if (isLoadingMoreRestaurants.value || !hasMoreRestaurants.value) return;
        isLoadingMoreRestaurants.value = true;
      } else {
        if (showLoading) isLoading.value = true;
        currentRestaurantPage.value = 1;
        hasMoreRestaurants.value = true;
      }

      error.value = '';

      final page = currentRestaurantPage.value;
      final response = await _apiService.get(
        'restaurants/restaurants/?page=$page',
      );

      List<dynamic> restaurantsList = [];

      if (response is List) {
        restaurantsList = response;
        hasMoreRestaurants.value = false; // Non-paged response
      } else if (response is Map) {
        restaurantsList = response['results'] ?? response['data'] ?? [];
        hasMoreRestaurants.value = response['next'] != null;
      }

      final newRestaurants = restaurantsList
          .map((json) => RestaurantProfile.fromJson(json))
          .toList();

      if (loadMore) {
        restaurants.addAll(newRestaurants);
        currentRestaurantPage.value++;
      } else {
        restaurants.value = newRestaurants;
        popularRestaurants.value = restaurants.take(5).toList();
        currentRestaurantPage.value = 2;
      }
    } catch (e) {
      error.value = 'Error fetching restaurants: $e';
    } finally {
      if (loadMore) {
        isLoadingMoreRestaurants.value = false;
      } else if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  Future<void> getRestaurantDetail(
    int restaurantId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      final now = DateTime.now();
      final cachedTime = _restaurantCacheTimestamps[restaurantId];
      final isCacheValid =
          cachedTime != null && now.difference(cachedTime) < _cacheDuration;

      if (_restaurantCache.containsKey(restaurantId) &&
          isCacheValid &&
          !forceRefresh) {
        selectedRestaurant.value = _restaurantCache[restaurantId];
        print('✅ Using cached restaurant details for ID: $restaurantId');
        return;
      }

      isLoadingDetails.value = true;
      error.value = '';

      final response = await _apiService.get(
        'restaurants/restaurants/$restaurantId/',
      );
      final restaurant = RestaurantProfile.fromJson(response);

      // Update cache
      _restaurantCache[restaurantId] = restaurant;
      _restaurantCacheTimestamps[restaurantId] = now;
      selectedRestaurant.value = restaurant;

      await getRestaurantCategories(restaurantId);
    } catch (e) {
      error.value = e.toString();

      // Fallback to cache even if stale when API fails
      if (_restaurantCache.containsKey(restaurantId)) {
        selectedRestaurant.value = _restaurantCache[restaurantId];
        print('🔄 API failed, using cached restaurant details');
      } else {
        rethrow;
      }
    } finally {
      isLoadingDetails.value = false;
    }
  }

  Future<void> preloadPopularRestaurantsDetails() async {
    try {
      // Preload details for popular restaurants
      for (final restaurant in popularRestaurants.take(3)) {
        if (!_restaurantCache.containsKey(restaurant.id)) {
          // Load in background without awaiting
          _apiService
              .get('restaurants/restaurants/${restaurant.id}/')
              .then((response) {
                final restaurantDetail = RestaurantProfile.fromJson(response);
                _restaurantCache[restaurant.id] = restaurantDetail;
                _restaurantCacheTimestamps[restaurant.id] = DateTime.now();
                print(
                  '✅ Preloaded details for restaurant: ${restaurant.restaurantName}',
                );
              })
              .catchError((e) {
                print('❌ Failed to preload restaurant ${restaurant.id}: $e');
              });
        }
      }
    } catch (e) {
      print('Error preloading restaurant details: $e');
    }
  }

  // In RestaurantController, update the getRestaurantCategories method:
  Future<void> getRestaurantCategories(
    int restaurantId, {
    bool forceRefresh = false,
  }) async {
    try {
      final categoryController = Get.find<CategoryController>();

      // Use the cached version from CategoryController
      final categoriesList = await categoryController.getRestaurantCategories(
        restaurantId,
        forceRefresh: forceRefresh,
      );

      categories.value = categoriesList;

      if (categoriesList.isNotEmpty) {
        final firstCategory = categoriesList.first;
        final categoryId = firstCategory.id;
        await getMenuItemsByCategory(restaurantId, categoryId);
      }
    } catch (e) {
      error.value = 'Error fetching restaurant categories: $e';
      print('Error fetching restaurant categories: $e');
    }
  }

  Future<void> getMenuItems({
    bool showLoading = false,
    bool loadMore = false,
  }) async {
    try {
      if (loadMore) {
        if (isLoadingMoreMenuItems.value || !hasMoreMenuItems.value) return;
        isLoadingMoreMenuItems.value = true;
      } else {
        if (showLoading) {
          isLoadingAllMenuItems.value = true;
          isLoadingMenuItems.value = true;
        }
        currentMenuItemsPage.value = 1;
        hasMoreMenuItems.value = true;
      }

      error.value = '';

      final page = currentMenuItemsPage.value;
      final response = await _apiService.get('restaurants/items/?page=$page');

      List<dynamic> menuItemsList = [];

      if (response is List) {
        menuItemsList = response;
        hasMoreMenuItems.value = false; // Non-paged response
      } else if (response is Map) {
        menuItemsList = response['results'] ?? response['data'] ?? [];
        hasMoreMenuItems.value = response['next'] != null;
      }

      final newList = menuItemsList
          .map((json) => MenuItem.fromJson(json))
          .toList();

      if (loadMore) {
        allMenuItems.addAll(newList);
        menuItems.addAll(newList);
        currentMenuItemsPage.value++;
      } else {
        allMenuItems.value = newList;
        menuItems.value = newList;
        currentMenuItemsPage.value = 2;
      }
    } catch (e) {
      error.value = 'Error fetching menu items: $e';
    } finally {
      if (loadMore) {
        isLoadingMoreMenuItems.value = false;
      } else if (showLoading) {
        isLoadingAllMenuItems.value = false;
        isLoadingMenuItems.value = false;
      }
    }
  }

  Future<void> getRestaurantMenuItems(int restaurantId) async {
    try {
      isLoadingRestaurantMenuItems.value = true;
      error.value = '';

      final response = await _apiService.get(
        'restaurants/restaurants/$restaurantId/items/',
      );
      print('Restaurant menu items response type: ${response.runtimeType}');

      List<dynamic> menuItemsList = [];

      if (response is List) {
        menuItemsList = response;
      } else if (response is Map && response.containsKey('data')) {
        menuItemsList = response['data'] ?? [];
      } else if (response is Map && response.containsKey('results')) {
        menuItemsList = response['results'] ?? [];
      } else if (response is Map) {
        final possibleLists = response.values
            .whereType<List>()
            .toList();
        if (possibleLists.isNotEmpty) {
          menuItemsList = possibleLists.first;
        }
      }

      restaurantMenuItems.value = menuItemsList
          .map((json) => MenuItem.fromJson(json))
          .toList();
    } catch (e) {
      error.value = 'Error fetching restaurant menu items: $e';
      print('Error fetching restaurant menu items: $e');
    } finally {
      isLoadingRestaurantMenuItems.value = false;
    }
  }

  Future<void> getMenuItemsByCategory(int restaurantId, int categoryId) async {
    try {
      isLoadingCategoryMenuItems.value = true;
      error.value = '';

      final response = await _apiService.get(
        'restaurants/restaurants/$restaurantId/categories/$categoryId/items/',
      );
      print('Category menu items response type: ${response.runtimeType}');

      List<dynamic> menuItemsList = [];

      if (response is List) {
        menuItemsList = response;
      } else if (response is Map && response.containsKey('data')) {
        menuItemsList = response['data'] ?? [];
      } else if (response is Map && response.containsKey('results')) {
        menuItemsList = response['results'] ?? [];
      } else if (response is Map) {
        final possibleLists = response.values
            .whereType<List>()
            .toList();
        if (possibleLists.isNotEmpty) {
          menuItemsList = possibleLists.first;
        }
      }

      categoryMenuItems.value = menuItemsList
          .map((json) => MenuItem.fromJson(json))
          .toList();
      menuItems.value = categoryMenuItems;
    } catch (e) {
      error.value = 'Error fetching category menu items: $e';
      print('Error fetching category menu items: $e');
    } finally {
      isLoadingCategoryMenuItems.value = false;
    }
  }

  Future<void> refreshRestaurants() async {
    await getRestaurants(showLoading: false);
  }

  Future<void> refreshMenuItems() async {
    await getMenuItems(showLoading: false);
  }

  // Add to RestaurantController
  Future<void> preloadPopularMenuItems() async {
    try {
      final menuController = Get.find<MenuItemController>();

      // Preload menu items from popular restaurants
      final popularItemIds = <int>[];

      for (final restaurant in popularRestaurants.take(3)) {
        // Get some menu items from each popular restaurant
        final restaurantItems = allMenuItems
            .where((item) => item.restaurantId == restaurant.id)
            .take(5)
            .map((item) => item.id)
            .toList();

        popularItemIds.addAll(restaurantItems);
      }

      // Also preload featured items
      final featuredItemIds = featuredItemsWithPromotions
          .take(10)
          .map((item) => item.id)
          .toList();

      popularItemIds.addAll(featuredItemIds);

      // Remove duplicates
      final uniqueIds = popularItemIds.toSet().toList();

      print('🔄 Preloading ${uniqueIds.length} popular menu items');
      await menuController.preloadMenuItems(uniqueIds);
    } catch (e) {
      print('Error preloading popular menu items: $e');
    }
  }

  // Clear cache methods
  void clearRestaurantCache() {
    _restaurantCache.clear();
    _restaurantCategoriesCache.clear();
    _restaurantCacheTimestamps.clear();
  }

  void clearStaleCache() {
    final now = DateTime.now();
    _restaurantCacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .forEach((entry) {
          _restaurantCache.remove(entry.key);
          _restaurantCategoriesCache.remove(entry.key);
          _restaurantCacheTimestamps.remove(entry.key);
        });
  }

  // Getters
  bool get isLoadingValue => isLoading.value;
  bool get isLoadingMenuItemsValue => isLoadingMenuItems.value;
  List<MenuItem> get allMenuItemsList => allMenuItems;
  List<MenuItem> get restaurantMenuItemsList => restaurantMenuItems;
  List<MenuItem> get categoryMenuItemsList => categoryMenuItems;
  bool get isLoadingAllMenuItemsValue => isLoadingAllMenuItems.value;
  bool get isLoadingRestaurantMenuItemsValue =>
      isLoadingRestaurantMenuItems.value;
  bool get isLoadingCategoryMenuItemsValue => isLoadingCategoryMenuItems.value;
}
