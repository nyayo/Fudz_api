import 'package:food_delivery_customer_app/models/cart.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/snackbar_service.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class CartController extends GetxController {
  final ApiService _apiService = Get.find();

  final Rx<Cart?> _cart = Rx<Cart?>(null);
  final Rx<Cart?> _localCart = Rx<Cart?>(
    null,
  ); // Local cart for immediate UI updates
  final RxBool isLoading = false.obs;
  final RxBool isSyncing = false.obs; // Track sync status
  final RxString error = ''.obs;

  static String _getCartKey(int userId) => 'cart_id_$userId';

  String? _getStoredCartId(int userId) {
    return GetStorage().read(_getCartKey(userId));
  }

  Future<void> _saveCartId(int userId, String cartId) async {
    await GetStorage().write(_getCartKey(userId), cartId);
  }

  Future<void> _clearCartId(int userId) async {
    await GetStorage().remove(_getCartKey(userId));
  }

  Cart? get cart =>
      _localCart.value ?? _cart.value; // Prefer local cart for display
  List<CartItem> get cartItems => cart?.items ?? [];
  int get cartItemCount {
    if (_localCart.value != null && _localCart.value!.items.isNotEmpty) {
      final count = _localCart.value!.items.fold(
        0,
        (sum, item) => sum + item.quantity,
      );
      print('🛒 cartItemCount calculated: $count');
      return count;
    } else if (_cart.value != null && _cart.value!.items.isNotEmpty) {
      final count = _cart.value!.items.fold(
        0,
        (sum, item) => sum + item.quantity,
      );
      print('🛒 cartItemCount calculated from remote: $count');
      return count;
    }
    print('🛒 cartItemCount: 0');
    return 0;
  }

  double get cartTotal => cart?.totalPrice ?? 0.0;
  bool get hasItems => cartItems.isNotEmpty;
  final RxMap<String, bool> _itemProcessingStates = <String, bool>{}.obs;

  // Add this to your CartController
  final RxBool isCheckingOut = false.obs;

  // Add this method to handle checkout process
  Future<bool> proceedToCheckout() async {
    try {
      isCheckingOut.value = true;
      error.value = '';

      // Simulate some processing time (you can remove this in production)
      await Future.delayed(const Duration(milliseconds: 500));

      // Your existing checkout logic would go here
      // For now, just return success
      return true;
    } catch (e) {
      error.value = e.toString();
      return false;
    } finally {
      isCheckingOut.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initializeLocalCart();

    // Listen for changes to force UI updates
    ever(_localCart, (_) {
      print('🛒 Local cart changed, updating badge count: $cartItemCount');
      update(); // This forces UI to rebuild
    });
  }

  void disposeSnackbars() {
    try {
      if (Get.isSnackbarOpen) {
        Get.closeAllSnackbars();
      }
    } catch (e) {
      print('Error closing snackbars: $e');
    }
  }

  // Initialize local cart from storage
  void _initializeLocalCart() {
    try {
      final localCartData = GetStorage().read('local_cart');
      if (localCartData != null) {
        _localCart.value = Cart.fromJson(localCartData);
        print('🛒 Local cart loaded: ${_localCart.value?.items.length} items');

        // Debug: Verify MenuItem data is preserved
        if (_localCart.value != null) {
          for (final item in _localCart.value!.items) {
            print('🛒 Loaded Item: ${item.menuItem.title}');
            print('   - Image URL: ${item.menuItem.imageUrl ?? "NULL"}');
            print('   - Restaurant: ${item.menuItem.restaurantName ?? "NULL"}');
          }
        }
      } else {
        _localCart.value = null;
        print('🛒 No local cart found in storage');
      }
    } catch (e) {
      print('❌ Error loading local cart: $e');
      _clearLocalCart();
    }
  }

  // Save local cart to storage
  void _saveLocalCart() {
    if (_localCart.value != null) {
      try {
        GetStorage().write('local_cart', _localCart.value!.toJson());
      } catch (e) {
        print('❌ Error saving local cart: $e');
      }
    } else {
      GetStorage().remove('local_cart');
    }
  }

  // Clear local cart
  void _clearLocalCart() {
    _localCart.value = null;
    GetStorage().remove('local_cart');
  }

  // Create a local cart item
  CartItem _createLocalCartItem({
    required MenuItem menuItem,
    required int quantity,
  }) {
    // Use discounted price if promotion is active, otherwise use regular price
    final unitPrice = menuItem.hasActivePromotions
        ? menuItem.discountedPrice
        : menuItem.price;

    return CartItem(
      id: 'local_${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      menuItem: menuItem,
      quantity: quantity,
      totalPrice: unitPrice * quantity,
      unitPrice: unitPrice,
    );
  }

  // Create a local cart
  Cart _createLocalCart() {
    return Cart(
      id: 'local_cart_${DateTime.now().millisecondsSinceEpoch}',
      items: [],
      totalPrice: 0.0,
      createdAt: DateTime.now(),
    );
  }

  // In CartController, update the addToCart method:

  Future<bool> addToCart({
    required MenuItem menuItem,
    required int quantity,
    String? accessToken,
    int? userId,
  }) async {
    final itemKey = '${menuItem.id}_add';

    try {
      _setItemProcessing(itemKey, true);
      error.value = '';

      print('🛒 Adding ${menuItem.title} to cart, quantity: $quantity');

      // 1. FIRST: Add to local cart for immediate UI update
      await _addToLocalCart(menuItem: menuItem, quantity: quantity);

      print('🛒 Local cart updated. Item count: $cartItemCount');

      // 2. Wait for 2 seconds to show loading indicator
      await Future.delayed(const Duration(seconds: 2));

      // 3. Show feedback after delay
      String successMessage = '${menuItem.title} added to cart';
      if (menuItem.hasActivePromotions) {
        successMessage +=
            ' with ${menuItem.activePromotions.first.formattedDiscount} discount!';
      }
      SnackbarService.showSuccess(successMessage);

      // 3. THEN: Sync with backend in background if we have access token
      if (accessToken != null && accessToken.isNotEmpty) {
        _syncWithBackend(accessToken: accessToken, userId: userId);
      }

      return true;
    } catch (e) {
      error.value = e.toString();
      // If local add failed, revert any changes
      _revertLocalChanges();
      SnackbarService.showError('Failed to add to cart: ${e.toString()}');
      return false;
    } finally {
      _setItemProcessing(itemKey, false);
    }
  }

  Future _addToLocalCart({
    required MenuItem menuItem,
    required int quantity,
  }) async {
    // Create or get local cart
    if (_localCart.value == null) {
      _localCart.value = _createLocalCart();
    }

    // Debug logging for promotion status
    print('🛒 MenuItem: ${menuItem.title}');
    print('🛒 Original Price: \$${menuItem.price}');
    print('🛒 Has Active Promotions: ${menuItem.hasActivePromotions}');
    print('🛒 Active Promotions Count: ${menuItem.activePromotions.length}');
    if (menuItem.hasActivePromotions) {
      print('🛒 Discounted Price: \$${menuItem.discountedPrice}');
      for (var promo in menuItem.activePromotions) {
        print(
          '🛒 Promotion: ${promo.name}, Discount: ${promo.discount}%, Active: ${promo.isCurrentlyActive}',
        );
      }
    }

    // Use discounted price if promotion is active
    final unitPrice = menuItem.hasActivePromotions
        ? menuItem.discountedPrice
        : menuItem.price;

    print('🛒 Using Unit Price: \$$unitPrice');

    final existingItemIndex = _localCart.value!.items.indexWhere(
      (item) => item.menuItem.id == menuItem.id,
    );

    if (existingItemIndex != -1) {
      // Update existing item
      final existingItem = _localCart.value!.items[existingItemIndex];
      final newQuantity = existingItem.quantity + quantity;
      final newTotalPrice = unitPrice * newQuantity;

      _localCart.value!.items[existingItemIndex] = CartItem(
        id: existingItem.id,
        menuItem: menuItem,
        quantity: newQuantity,
        totalPrice: newTotalPrice,
        unitPrice: unitPrice,
      );
    } else {
      // Add new item
      final newItem = _createLocalCartItem(
        menuItem: menuItem,
        quantity: quantity,
      );
      _localCart.value!.items.add(newItem);
    }

    // Recalculate total
    _recalculateLocalCartTotal();

    // Save to local storage
    _saveLocalCart();

    // Force UI update
    _localCart.refresh();
    update();

    print(
      '🛒 Local cart updated: ${_localCart.value!.items.length} items, Total: \$${_localCart.value!.totalPrice}',
    );
    print('🛒 Badge should show: $cartItemCount items');
  }

  // Recalculate local cart total
  void _recalculateLocalCartTotal() {
    if (_localCart.value != null) {
      final total = _localCart.value!.items.fold(
        0.0,
        (sum, item) => sum + item.totalPrice,
      );
      _localCart.value = _localCart.value!.copyWith(totalPrice: total);
    }
  }

  // Sync local cart with backend
  Future<void> _syncWithBackend({required String accessToken, int? userId}) async {
    if (_localCart.value == null || _localCart.value!.items.isEmpty) return;

    try {
      isSyncing.value = true;
      print('🔄 Syncing local cart with backend...');

      String cartId = userId != null ? _getStoredCartId(userId) : GetStorage().read('current_cart_id');
      
      if (cartId == null || _cart.value == null) {
        final cartResponse = await _apiService.post('orders/carts/', {});
        cartId = cartResponse['id'];
        
        if (userId != null) {
          await _saveCartId(userId, cartId);
        } else {
          await GetStorage().write('current_cart_id', cartId);
        }
        _cart.value = Cart.fromJson(cartResponse);
      }

      // Sync each item with backend
      for (final localItem in _localCart.value!.items) {
        if (localItem.id.startsWith('local_')) {
          // This is a local item that needs to be synced
          try {
            final response = await _apiService.post(
              'orders/carts/$cartId/items/',
              {
                'menu_item_id': localItem.menuItem.id,
                'qty': localItem.quantity,
              },
            );

            print('✅ Synced item: ${localItem.menuItem.title}');
          } catch (e) {
            print(
              '❌ Failed to sync item: ${localItem.menuItem.title}, Error: $e',
            );
            // Continue with other items even if one fails
          }
        }
      }

      // Refresh remote cart to get updated data
      await getCart(userId: userId);

      // Merge local cart with remote cart
      await _mergeCarts();

      print('✅ Cart sync completed');
    } catch (e) {
      print('❌ Cart sync failed: $e');
      // Don't show error to user - local cart will continue to work
    } finally {
      isSyncing.value = false;
    }
  }

  // Merge local and remote carts, preserving rich local data
  Future<void> _mergeCarts() async {
    print('🔄 _mergeCarts called');
    if (_cart.value == null) {
      print('❌ Remote cart is null, skipping merge');
      return;
    }

    if (_localCart.value == null) {
      print('❌ Local cart is null, nothing to preserve');
      // If local cart is missing but we have remote cart, just save remote as local
      _localCart.value = _cart.value;
      _saveLocalCart();
      return;
    }

    print(
      '📊 merging: Remote Items: ${_cart.value!.items.length}, Local Items: ${_localCart.value!.items.length}',
    );

    // Build a map of local menu items for quick lookup
    final localMenuItemsById = <int, MenuItem>{};
    for (final item in _localCart.value!.items) {
      localMenuItemsById[item.menuItem.id] = item.menuItem;
      print(
        '📍 Local Item [${item.menuItem.id}]: ${item.menuItem.title}, Has Image: ${item.menuItem.imageUrl != null}, Restaurant: ${item.menuItem.restaurantName}',
      );
    }

    // Merge remote cart items with local menu item data
    final mergedItems = <CartItem>[];
    for (final remoteItem in _cart.value!.items) {
      final localMenuItem = localMenuItemsById[remoteItem.menuItem.id];
      print(
        '🔗 Processing Remote Item [${remoteItem.menuItem.id}]: ${remoteItem.menuItem.title}',
      );

      if (localMenuItem != null &&
          (localMenuItem.imageUrl != null ||
              localMenuItem.restaurantName != null)) {
        // Use local menu item data which has more info (image, description, etc.)
        print(
          '✅ Preserving local data for: ${localMenuItem.title}, Restaurant: ${localMenuItem.restaurantName}',
        );
        mergedItems.add(
          CartItem(
            id: remoteItem.id,
            menuItem: localMenuItem,
            quantity: remoteItem.quantity,
            totalPrice: remoteItem.totalPrice,
            unitPrice: remoteItem.unitPrice,
          ),
        );
      } else {
        // Use remote item as-is (new item or no local data)
        print('⚠️ Using remote data (no rich local data found)');
        mergedItems.add(remoteItem);
      }
    }

    // Update local cart with merged items
    _localCart.value = Cart(
      id: _cart.value!.id,
      items: mergedItems,
      totalPrice: _cart.value!.totalPrice,
      restaurantId: _cart.value!.restaurantId,
      createdAt: _cart.value!.createdAt,
    );
    _saveLocalCart();
  }

  // Revert local changes in case of error
  void _revertLocalChanges() {
    _initializeLocalCart(); // Reload from storage
  }

  // FAST LOCAL QUANTITY UPDATE
  Future<void> updateQuantity({
    required String itemId,
    required int quantity,
    String? accessToken,
    int? userId,
  }) async {
    final itemKey = '${itemId}_update';

    try {
      _setItemProcessing(itemKey, true);

      // 1. FIRST: Update locally
      await _updateLocalQuantity(itemId: itemId, quantity: quantity);

      // 2. THEN: Sync with backend if we have access token
      if (accessToken != null && accessToken.isNotEmpty) {
        _syncQuantityWithBackend(
          itemId: itemId,
          quantity: quantity,
          accessToken: accessToken,
          userId: userId,
        );
      }
    } catch (e) {
      error.value = e.toString();
      _revertLocalChanges();
      rethrow;
    } finally {
      _setItemProcessing(itemKey, false);
    }
  }

  Future _updateLocalQuantity({
    required String itemId,
    required int quantity,
  }) async {
    if (_localCart.value == null) return;

    final itemIndex = _localCart.value!.items.indexWhere(
      (item) => item.id == itemId,
    );

    if (itemIndex != -1) {
      if (quantity <= 0) {
        // Remove item
        _localCart.value!.items.removeAt(itemIndex);
      } else {
        // Update quantity
        final item = _localCart.value!.items[itemIndex];

        // Use discounted price if promotion is active
        final unitPrice = item.menuItem.hasActivePromotions
            ? item.menuItem.discountedPrice
            : item.menuItem.price;

        _localCart.value!.items[itemIndex] = CartItem(
          id: item.id,
          menuItem: item.menuItem,
          quantity: quantity,
          totalPrice: unitPrice * quantity,
          unitPrice: unitPrice,
        );
      }

      _recalculateLocalCartTotal();
      _saveLocalCart();
      _localCart.refresh();
    }
  }

  // Sync quantity with backend
  Future<void> _syncQuantityWithBackend({
    required String itemId,
    required int quantity,
    required String accessToken,
    int? userId,
  }) async {
    if (!itemId.startsWith('local_')) {
      // This is already a remote item, update directly
      try {
        final cartId = userId != null ? _getStoredCartId(userId) : GetStorage().read('current_cart_id');
        if (cartId == null) return;

        if (quantity <= 0) {
          await _apiService.delete('orders/carts/$cartId/items/$itemId/');
        } else {
          await _apiService.patch('orders/carts/$cartId/items/$itemId/', {
            'qty': quantity,
          });
        }

        await getCart(userId: userId); // Refresh remote cart
        await _mergeCarts(); // Update local cart with remote data
      } catch (e) {
        print('❌ Failed to sync quantity: $e');
      }
    }
    // For local items, they will be synced in the next full sync
  }

  // FAST LOCAL REMOVE FROM CART
  Future<void> removeFromCart({
    required String itemId,
    String? accessToken,
    int? userId,
  }) async {
    final itemKey = '${itemId}_remove';

    try {
      _setItemProcessing(itemKey, true);

      // 1. FIRST: Remove locally
      await _removeFromLocalCart(itemId: itemId);

      // 2. THEN: Sync with backend if we have access token
      if (accessToken != null && accessToken.isNotEmpty) {
        _syncRemoveWithBackend(itemId: itemId, accessToken: accessToken, userId: userId);
      }

      Get.snackbar(
        'Removed',
        'Item removed from cart',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      error.value = e.toString();
      _revertLocalChanges();
      rethrow;
    } finally {
      _setItemProcessing(itemKey, false);
    }
  }

  // Remove item locally
  Future<void> _removeFromLocalCart({required String itemId}) async {
    if (_localCart.value == null) return;

    _localCart.value!.items.removeWhere((item) => item.id == itemId);
    _recalculateLocalCartTotal();
    _saveLocalCart();
    _localCart.refresh();
  }

  // Sync remove with backend
  Future<void> _syncRemoveWithBackend({
    required String itemId,
    required String accessToken,
    int? userId,
  }) async {
    if (!itemId.startsWith('local_')) {
      // This is a remote item, remove directly
      try {
        final cartId = userId != null ? _getStoredCartId(userId) : GetStorage().read('current_cart_id');
        if (cartId == null) return;

        await _apiService.delete('orders/carts/$cartId/items/$itemId/');
        await getCart(userId: userId); // Refresh remote cart
        await _mergeCarts(); // Update local cart with remote data
      } catch (e) {
        print('❌ Failed to sync remove: $e');
      }
    }
    // For local items, they will be synced in the next full sync
  }

  // Existing methods with local-first approach
  Future<void> initializeCart({int? userId, String? accessToken}) async {
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await getCart(userId: userId);

        if (_cart.value != null) {
          await _mergeCarts();
        }
      }
    } catch (e) {
      print('Error initializing cart: $e');
    }
  }

  Future<void> getCart({int? userId}) async {
    try {
      final cartId = userId != null ? _getStoredCartId(userId) : GetStorage().read('current_cart_id');

      if (cartId != null) {
        final response = await _apiService.get('orders/carts/$cartId/');
        _cart.value = Cart.fromJson(response);
      }
    } catch (e) {
      print('Error getting cart: $e');
      // Don't throw error - we'll use local cart
    }
  }

  Future<void> clearCart({int? userId, String? accessToken}) async {
    try {
      _clearLocalCart();

      final cartId = userId != null ? _getStoredCartId(userId) : GetStorage().read('current_cart_id');
      
      if (accessToken != null && accessToken.isNotEmpty && cartId != null) {
        await _apiService.delete('orders/carts/$cartId/');
      }

      _cart.value = null;
      
      if (userId != null) {
        await _clearCartId(userId);
      } else {
        await GetStorage().remove('current_cart_id');
      }

      Get.snackbar('Cleared', 'Cart cleared');
    } catch (e) {
      error.value = e.toString();
      rethrow;
    }
  }

  Future<void> clearCartForUser(int userId) async {
    await clearCart(userId: userId);
  }

  // Rest of your existing methods...
  bool isItemProcessing(String itemId) {
    // Access via .value to trigger Obx rebuilds
    return _itemProcessingStates.value[itemId] ?? false;
  }

  bool isItemInCart(int menuItemId) {
    if (_localCart.value != null) {
      return _localCart.value!.items.any(
        (item) => item.menuItem.id == menuItemId,
      );
    }
    if (_cart.value != null) {
      return _cart.value!.items.any((item) => item.menuItem.id == menuItemId);
    }
    return false;
  }

  int getItemQuantity(int menuItemId) {
    if (_localCart.value != null) {
      final item = _localCart.value!.items.cast<CartItem?>().firstWhere(
        (item) => item!.menuItem.id == menuItemId,
        orElse: () => null,
      );
      return item?.quantity ?? 0;
    }
    if (_cart.value != null) {
      final item = _cart.value!.items.cast<CartItem?>().firstWhere(
        (item) => item!.menuItem.id == menuItemId,
        orElse: () => null,
      );
      return item?.quantity ?? 0;
    }
    return 0;
  }

  String? getCartItemId(int menuItemId) {
    if (_localCart.value != null) {
      final item = _localCart.value!.items.cast<CartItem?>().firstWhere(
        (item) => item!.menuItem.id == menuItemId,
        orElse: () => null,
      );
      return item?.id;
    }
    if (_cart.value != null) {
      final item = _cart.value!.items.cast<CartItem?>().firstWhere(
        (item) => item!.menuItem.id == menuItemId,
        orElse: () => null,
      );
      return item?.id;
    }
    return null;
  }

  void _setItemProcessing(String itemId, bool processing) {
    _itemProcessingStates[itemId] = processing;
    _itemProcessingStates.refresh(); // Force reactive update
  }

  void clearCartLocally() {
    _localCart.value = null;
    _cart.value = null;
    _clearLocalCart();
    print('🛒 Cart cleared locally');
  }

  bool get isLoadingValue => isLoading.value;
  bool get isSyncingValue => isSyncing.value;
}
