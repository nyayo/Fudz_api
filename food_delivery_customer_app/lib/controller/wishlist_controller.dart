import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/wishlist.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/snackbar_service.dart';

import 'package:get/get.dart';

import 'package:get_storage/get_storage.dart';

class WishlistController extends GetxController {
  final ApiService _apiService = Get.find();
  static const String _localWishlistOwnerKey = 'local_wishlist_owner';

  final Rx<Wishlist?> _wishlist = Rx<Wishlist?>(null);
  final Rx<Wishlist?> _localWishlist = Rx<Wishlist?>(
    null,
  ); // Local wishlist for immediate UI
  final RxBool isLoading = false.obs;
  final RxBool isSyncing = false.obs; // Track sync status
  final RxString error = ''.obs;
  final RxMap<String, bool> _itemProcessingStates = <String, bool>{}.obs;
  
  // Track current user ID for data isolation
  int? _currentUserId;

  Wishlist? get wishlist =>
      _localWishlist.value ?? _wishlist.value; // Prefer local for display
  List<WishlistItem> get wishlistItems => wishlist?.items ?? [];
  int get wishlistItemCount => wishlistItems.length;
  bool get hasItems => wishlistItems.isNotEmpty;

  String _getWishlistStorageKey(int userId) => 'local_wishlist_user_$userId';

  @override
  void onInit() {
    super.onInit();
    _initializeLocalWishlist();
  }

  // Initialize local wishlist from storage - user-specific
  void _initializeLocalWishlist({int? userId}) {
    final storageKey = userId != null ? _getWishlistStorageKey(userId) : 'local_wishlist';
    final localWishlistData = GetStorage().read(storageKey);
    if (localWishlistData != null) {
      try {
        _localWishlist.value = Wishlist.fromJson(localWishlistData);
        print(
          '❤️ Local wishlist loaded: ${_localWishlist.value?.items.length} items',
        );
      } catch (e) {
        print('❌ Error loading local wishlist: $e');
        _clearLocalWishlist(userId: userId);
      }
    }
  }

  // Save local wishlist to storage - user-specific
  void _saveLocalWishlist({int? userId}) {
    if (_localWishlist.value != null) {
      try {
        final storageKey = userId != null ? _getWishlistStorageKey(userId) : 'local_wishlist';
        GetStorage().write(storageKey, _localWishlist.value!.toJson());
      } catch (e) {
        print('❌ Error saving local wishlist: $e');
      }
    } else {
      final storageKey = userId != null ? _getWishlistStorageKey(userId) : 'local_wishlist';
      GetStorage().remove(storageKey);
    }
  }

  // Clear local wishlist - user-specific
  void _clearLocalWishlist({int? userId}) {
    _localWishlist.value = null;
    final storageKey = userId != null ? _getWishlistStorageKey(userId) : 'local_wishlist';
    GetStorage().remove(storageKey);
  }

  String _resolveOwnerId(UserController userController) {
    return userController.user?.id.toString() ??
        userController.user?.email ??
        userController.accessToken ??
        '';
  }

  Future<void> _ensureWishlistOwner(String ownerId, {int? userId}) async {
    if (ownerId.isEmpty) return;
    final storage = GetStorage();
    final previousOwner = storage.read(_localWishlistOwnerKey);
    if (previousOwner != ownerId) {
      _clearLocalWishlist(userId: userId);
      await storage.write(_localWishlistOwnerKey, ownerId);
      _currentUserId = userId;
    }
  }

  // Create a local wishlist item
  WishlistItem _createLocalWishlistItem({required MenuItem menuItem}) {
    return WishlistItem(
      id: 'local_${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      wishlistId: 0,
      menuItem: menuItem,
      addedAt: DateTime.now(),
    );
  }

  // Create a local wishlist
  Wishlist _createLocalWishlist() {
    return Wishlist(
      id: 'local_wishlist_${DateTime.now().millisecondsSinceEpoch}',
      userId: 0,
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // FAST LOCAL TOGGLE WISHLIST - Immediate UI update
  // In WishlistController, update the toggleWishlist method:

  // In WishlistController, update the toggleWishlist method:

  Future<void> toggleWishlist({
    required MenuItem menuItem,
    required String? accessToken,
  }) async {
    final itemKey = '${menuItem.id}_toggle';

    try {
      _setItemProcessing(itemKey, true);
      error.value = '';

      // Check if user is logged in
      final userController = Get.find<UserController>();
      if (!userController.isLoggedIn) {
        SnackbarService.showError('Please login to manage wishlist');
        return;
      }

      final userId = userController.user?.id;
      await _ensureWishlistOwner(_resolveOwnerId(userController), userId: userId);

      // 1. FIRST: Check current state
      final wasInWishlist = isItemInWishlist(menuItem.id);

      // 2. Toggle locally for immediate UI update
      if (wasInWishlist) {
        await _removeFromLocalWishlist(menuItemId: menuItem.id);
      } else {
        await _addToLocalWishlist(menuItem: menuItem);
      }

      // 3. Show immediate feedback with proper message
      if (wasInWishlist) {
        SnackbarService.showWarning('Removed from wishlist');
      } else {
        SnackbarService.showSuccess('Added to wishlist');
      }

      // 4. THEN: Sync with backend in background
      if (accessToken != null && accessToken.isNotEmpty) {
        _syncWithBackend(
          menuItem: menuItem,
          wasInWishlist: wasInWishlist,
          accessToken: accessToken,
        );
      }
    } catch (e) {
      error.value = e.toString();
      // If local toggle failed, revert any changes
      _revertLocalChanges();
      SnackbarService.showError('Failed to update wishlist');
      rethrow;
    } finally {
      _setItemProcessing(itemKey, false);
    }
  }

  // Add item to local wishlist (immediate)
  Future<void> _addToLocalWishlist({required MenuItem menuItem}) async {
    // Create or get local wishlist
    if (_localWishlist.value == null) {
      _localWishlist.value = _createLocalWishlist();
    }

    // Check if item already exists locally
    final existingItemIndex = _localWishlist.value!.items.indexWhere(
      (item) => item.menuItem.id == menuItem.id,
    );

    if (existingItemIndex == -1) {
      // Add new item
      final newItem = _createLocalWishlistItem(menuItem: menuItem);
      _localWishlist.value!.items.add(newItem);

      // Save to local storage
      _saveLocalWishlist();

      // Force UI update
      _localWishlist.refresh();

      print(
        '❤️ Local wishlist updated: ${_localWishlist.value!.items.length} items',
      );
    }
  }

  // Remove item from local wishlist (immediate)
  Future<void> _removeFromLocalWishlist({required int menuItemId}) async {
    if (_localWishlist.value == null) return;

    _localWishlist.value!.items.removeWhere(
      (item) => item.menuItem.id == menuItemId,
    );

    // Save to local storage
    _saveLocalWishlist();

    // Force UI update
    _localWishlist.refresh();

    print(
      '❤️ Local wishlist updated: ${_localWishlist.value!.items.length} items',
    );
  }

  Future<void> _syncWithBackend({
    required MenuItem menuItem,
    required bool wasInWishlist,
    required String accessToken,
  }) async {
    try {
      isSyncing.value = true;
      print('🔄 Syncing wishlist with backend...');

      await _performWishlistRequestWithRetry(() async {
        if (wasInWishlist) {
          await _apiService.delete('wishlists/remove/${menuItem.id}/');
          print('✅ Removed from backend wishlist: ${menuItem.title}');
        } else {
          await _apiService.post('wishlists/add/', {'menu_item_id': menuItem.id});
          print('✅ Added to backend wishlist: ${menuItem.title}');
        }
      });

      // Refresh remote wishlist to get updated data
      await loadWishlist(accessToken);

      // Merge local wishlist with remote wishlist
      await _mergeWishlists();

      print('✅ Wishlist sync completed');
    } catch (e) {
      print('❌ Wishlist sync failed: $e');

      // Handle specific errors
      if (e.toString().contains('already in wishlist')) {
        print('⚠️ Item already in backend wishlist, refreshing state...');
        await loadWishlist(accessToken);
        await _mergeWishlists();
      } else if (e.toString().contains('not found') ||
          e.toString().contains('404')) {
        print('⚠️ Item not found on backend, removing from local');
        await _removeFromLocalWishlist(menuItemId: menuItem.id);
      } else {
        // Keep optimistic UI and retry reconciliation shortly in background.
        Future.delayed(const Duration(milliseconds: 700), () async {
          try {
            await loadWishlist(accessToken);
            await _mergeWishlists();
          } catch (_) {}
        });
      }
    } finally {
      isSyncing.value = false;
    }
  }

  bool _isTransientWishlistError(String errorText) {
    final e = errorText.toLowerCase();
    return e.contains('403') ||
        e.contains('401') ||
        e.contains('timeout') ||
        e.contains('socket') ||
        e.contains('network') ||
        e.contains('connection');
  }

  Future<void> _performWishlistRequestWithRetry(
    Future<void> Function() action,
  ) async {
    Object? lastError;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        await action();
        return;
      } catch (e) {
        lastError = e;
        if (attempt == 2 || !_isTransientWishlistError(e.toString())) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  // Merge local and remote wishlists
  Future<void> _mergeWishlists() async {
    if (_wishlist.value == null || _localWishlist.value == null) return;

    // For now, just replace local wishlist with remote wishlist after sync
    // You can implement more sophisticated merging logic here
    _localWishlist.value = _wishlist.value;
    _saveLocalWishlist(userId: _currentUserId);
  }

  // Revert local changes in case of error
  void _revertLocalChanges() {
    _initializeLocalWishlist(userId: _currentUserId); // Reload from storage
  }

  // Load wishlist from backend (existing method with local merge)
  Future<void> loadWishlist(String? accessToken) async {
    try {
      // Check if user is logged in using UserController
      final userController = Get.find<UserController>();
      if (!userController.isLoggedIn) {
        print('🛍️ User not logged in, skipping wishlist load');
        _wishlist.value = null;
        _localWishlist.value = null;
        GetStorage().remove(_localWishlistOwnerKey);
        _currentUserId = null;
        return;
      }

      // If no accessToken provided, try to get it from UserController
      final token = accessToken ?? userController.accessToken;
      if (token == null || token.isEmpty) {
        print('🛍️ No access token available, skipping wishlist load');
        _wishlist.value = null;
        return;
      }

      final userId = userController.user?.id;
      
      // If user changed, clear previous user's local wishlist first
      if (userId != null && _currentUserId != null && _currentUserId != userId) {
        print('🛍️ User changed from $_currentUserId to $userId, clearing previous wishlist');
        _clearLocalWishlist(userId: _currentUserId);
      }
      
      _currentUserId = userId;
      await _ensureWishlistOwner(_resolveOwnerId(userController), userId: userId);

      isLoading.value = true;
      error.value = '';

      print('🛍️ Loading wishlist for user: ${userController.user?.email}');
      final response = await _apiService.get('wishlists/');
      print('🛍️ Wishlist API response type: ${response.runtimeType}');

      // Handle different response formats
      if (response == null) {
        print('🛍️ Wishlist API returned null');
        _wishlist.value = null;
        return;
      }

      Wishlist? remoteWishlist;

      // If response has a data field (most common)
      if (response is Map && response.containsKey('data')) {
        print('🛍️ Response has data field');
        final data = response['data'];
        if (data is List && data.isNotEmpty) {
          // Create a wishlist wrapper for the data array
          remoteWishlist = Wishlist(
            id: '1', // Default ID
            userId: 0,
            items: data.map((item) {
              try {
                return WishlistItem.fromJson(item);
              } catch (e) {
                print('🛍️ Error parsing wishlist item: $e');
                print('🛍️ Problematic item: $item');
                // Return a dummy item to prevent complete failure
                return WishlistItem(
                  id: 'error',
                  wishlistId: 0,
                  menuItem: MenuItem(
                    id: 0,
                    title: 'Error loading item',
                    price: 0.0,
                    isAvailable: false,
                    category: 0,
                    images: [],
                    promotions: [],
                  ),
                  addedAt: DateTime.now(),
                );
              }
            }).toList(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          remoteWishlist = null;
        }
      }
      // If response is a list directly
      else if (response is List) {
        print('🛍️ Response is List with ${response.length} items');
        if (response.isNotEmpty) {
          remoteWishlist = Wishlist.fromJson(response.first);
        } else {
          remoteWishlist = null;
        }
      } else {
        print(
          '🛍️ Unexpected wishlist response format: ${response.runtimeType}',
        );
        remoteWishlist = null;
      }

      _wishlist.value = remoteWishlist;

      // Merge with local wishlist
      if (remoteWishlist != null) {
        _localWishlist.value = remoteWishlist;
        _saveLocalWishlist();
      }

      print(
        '🛍️ Wishlist loaded successfully. Item count: $wishlistItemCount',
      );
    } catch (e) {
      error.value = 'Error loading wishlist: $e';
      print('🛍️ Error loading wishlist: $e');
      _wishlist.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  // Individual add/remove methods for direct backend operations
  Future<void> addToWishlist({
    required MenuItem menuItem,
    required String? accessToken,
  }) async {
    await toggleWishlist(menuItem: menuItem, accessToken: accessToken);
  }

  // In WishlistController, update the removeFromWishlist method:

  Future<void> removeFromWishlist({
    required int menuItemId,
    required String? accessToken,
  }) async {
    try {
      // Instead of creating a temp menu item, find the actual menu item from the wishlist
      final wishlistItem = wishlistItems.firstWhereOrNull(
        (item) => item.menuItem.id == menuItemId,
      );

      if (wishlistItem != null) {
        // Use the actual menu item from the wishlist
        await toggleWishlist(
          menuItem: wishlistItem.menuItem,
          accessToken: accessToken,
        );
      } else {
        // Fallback: create a minimal menu item if not found
        final tempMenuItem = MenuItem(
          id: menuItemId,
          title: 'Item',
          price: 0.0,
          isAvailable: true,
          category: 0,
          images: [],
          promotions: [],
        );

        await toggleWishlist(menuItem: tempMenuItem, accessToken: accessToken);
      }
    } catch (e) {
      error.value = e.toString();
      SnackbarService.showError('Failed to remove from wishlist');
      rethrow;
    }
  }

  bool isItemInWishlist(int menuItemId) {
    return wishlistItems.any((item) => item.menuItem.id == menuItemId);
  }

  // Check if item is being processed
  bool isItemProcessing(String itemId) {
    return _itemProcessingStates[itemId] ?? false;
  }

  void _setItemProcessing(String itemId, bool processing) {
    _itemProcessingStates[itemId] = processing;
  }

  // Clear wishlist locally (useful for logout)
  void clearWishlist() {
    _wishlist.value = null;
    _localWishlist.value = null;
    _clearLocalWishlist(userId: _currentUserId);
    GetStorage().remove(_localWishlistOwnerKey);
    _currentUserId = null;
    print('❤️ Wishlist cleared locally');
  }

  // Initialize wishlist services
  Future<void> initializeWishlist({required String? accessToken}) async {
    try {
      final userController = Get.find<UserController>();
      final userId = userController.user?.id;
      
      // If this is a new user (different from current), clear previous wishlist
      if (userId != null && _currentUserId != null && _currentUserId != userId) {
        _clearLocalWishlist(userId: _currentUserId);
        _wishlist.value = null;
        _localWishlist.value = null;
      }
      
      // Only try to get existing wishlist from backend if we have access token
      if (accessToken != null && accessToken.isNotEmpty) {
        await loadWishlist(accessToken);
      }
    } catch (e) {
      print('Error initializing wishlist: $e');
      // Continue with local wishlist if backend fails
    }
  }

  bool get isLoadingValue => isLoading.value;
  bool get isSyncingValue => isSyncing.value;
}
