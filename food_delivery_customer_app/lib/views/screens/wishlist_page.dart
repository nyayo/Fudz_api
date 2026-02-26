// views/screens/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/wishlist.dart';

import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';

import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:get/get.dart';

class WishlistPage extends StatelessWidget {
  WishlistPage({super.key});

  final WishlistController _wishlistController = Get.find<WishlistController>();
  final UserController _userController = Get.find<UserController>();
  final CartController _cartController = Get.find<CartController>();

  @override
  Widget build(BuildContext context) {
    print(
      '🏠 WishlistPage built - User logged in: ${_userController.isLoggedIn}',
    );
    print(
      '🏠 WishlistPage built - Item count: ${_wishlistController.wishlistItemCount}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Obx(() {
        print(
          '🔄 WishlistPage Obx rebuilding - Loading: ${_wishlistController.isLoading}',
        );
        print(
          '🔄 WishlistPage Obx rebuilding - Error: ${_wishlistController.error}',
        );
        print(
          '🔄 WishlistPage Obx rebuilding - Item count: ${_wishlistController.wishlistItemCount}',
        );

        if (!_userController.isLoggedIn) {
          print('🔒 User not logged in, showing login required');
          return _buildLoginRequired();
        }

        if (_wishlistController.isLoading.value) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => MenuItemCardShimmer(),
          );
        }

        if (_wishlistController.error.isNotEmpty) {
          print('❌ Wishlist error: ${_wishlistController.error}');
          return _buildErrorState();
        }

        if (_wishlistController.wishlistItemCount == 0) {
          print('📭 Wishlist is empty');
          return _buildEmptyWishlist();
        }

        print(
          '✅ Displaying ${_wishlistController.wishlistItemCount} wishlist items',
        );
        return _buildWishlistItems();
      }),
    );
  }

  // Add this error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 20),
          Text(
            'Error Loading Wishlist',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Obx(
            () => Text(
              _wishlistController.error.value,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              if (_userController.isLoggedIn) {
                _wishlistController.loadWishlist(_userController.accessToken);
              }
            },
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Login Required',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please login to view your wishlist',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              // Navigate to login page
              Get.to(() => const GetStarted());
            },
            child: const Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWishlist() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start adding your favorite items!',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              Get.to(AllMenuItemsPage()); // Go to home
            },
            child: const Text(
              'Browse Menu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistItems() {
    final wishlist = _wishlistController.wishlist;
    if (wishlist == null || wishlist.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items in wishlist',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      // Use safe access pattern for length
      itemCount: wishlist.items.length,
      itemBuilder: (context, index) {
        // Access items list only once and store in local variable
        final items = wishlist.items;
        if (index >= items.length) return const SizedBox.shrink();

        return FadeSlideIn(
          duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 200)),
          child: _buildWishlistItemCard(items[index]),
        );
      },
    );
  }

  Widget _buildWishlistItemCard(WishlistItem wishlistItem) {
    final menuItem = wishlistItem.menuItem;
    final bool hasPromotion = menuItem.hasActivePromotions;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasPromotion
            ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Get.to(() => MenuItemDetailPage(menuItemId: menuItem.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image with Promotion Badge
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child:
                          menuItem.imageUrl != null &&
                              menuItem.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedImage(
                                imageUrl: menuItem.imageUrl,
                                fit: BoxFit.cover,
                                placeholderIcon: Icons.fastfood,
                              ),
                            )
                          : Icon(
                              Icons.fastfood,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                    ),
                    if (hasPromotion)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            menuItem.activePromotions.first.formattedDiscount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        menuItem.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TColor.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Promotion Banner
                      if (hasPromotion)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '🔥 ${menuItem.activePromotions.first.name}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Description
                      Text(
                        menuItem.description ?? 'Delicious food item',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Price
                      if (hasPromotion)
                        Row(
                          children: [
                            Text(
                              menuItem.formattedDiscountedPrice,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              menuItem.formattedPrice,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          menuItem.formattedPrice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: TColor.primary,
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Action Buttons
                      Row(
                        children: [
                          // Add to Cart Button / Quantity Counter
                          Expanded(
                            child: Obx(() {
                              final isProcessing = _cartController
                                  .isItemProcessing('${menuItem.id}_add');
                              final isInCart = _cartController.isItemInCart(
                                menuItem.id,
                              );

                              if (isInCart) {
                                // Show quantity counter
                                final quantity = _cartController
                                    .getItemQuantity(menuItem.id);
                                final cartItemId = _cartController
                                    .getCartItemId(menuItem.id);
                                final isUpdating = _cartController
                                    .isItemProcessing('${cartItemId}_update');

                                return Container(
                                  decoration: BoxDecoration(
                                    color: TColor.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: TColor.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Decrease / Remove button
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            quantity <= 1
                                                ? Icons.delete_outline
                                                : Icons.remove,
                                            color: quantity <= 1
                                                ? Colors.red
                                                : TColor.primary,
                                            size: 18,
                                          ),
                                          onPressed: isUpdating
                                              ? null
                                              : () {
                                                  if (cartItemId != null) {
                                                    _cartController
                                                        .updateQuantity(
                                                          itemId: cartItemId,
                                                          quantity:
                                                              quantity - 1,
                                                          accessToken:
                                                              _userController
                                                                  .accessToken,
                                                        );
                                                  }
                                                },
                                        ),
                                      ),
                                      // Quantity display
                                      isUpdating
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              '$quantity',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: TColor.primary,
                                              ),
                                            ),
                                      // Increase button
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.add,
                                            color: TColor.primary,
                                            size: 18,
                                          ),
                                          onPressed: isUpdating
                                              ? null
                                              : () {
                                                  if (cartItemId != null) {
                                                    _cartController
                                                        .updateQuantity(
                                                          itemId: cartItemId,
                                                          quantity:
                                                              quantity + 1,
                                                          accessToken:
                                                              _userController
                                                                  .accessToken,
                                                        );
                                                  }
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Show Add to Cart button
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TColor.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () async {
                                        await _cartController.addToCart(
                                          menuItem: menuItem,
                                          quantity: 1,
                                          accessToken:
                                              _userController.accessToken,
                                        );
                                      },
                                child: isProcessing
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Add to Cart',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),

                          // Remove from Wishlist Button
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 24,
                            ),
                            onPressed: () {
                              _wishlistController.removeFromWishlist(
                                menuItemId: menuItem.id,
                                accessToken: _userController.accessToken,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearWishlistDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear Wishlist'),
        content: const Text(
          'Are you sure you want to remove all items from your wishlist?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _clearAllWishlistItems();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAllWishlistItems() async {
    final items = _wishlistController.wishlist!.items.toList();
    for (final item in items) {
      await _wishlistController.removeFromWishlist(
        menuItemId: item.menuItem.id,
        accessToken: _userController.accessToken,
      );
    }
  }
}
