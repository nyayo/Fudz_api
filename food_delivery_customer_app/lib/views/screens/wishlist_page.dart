// views/screens/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/wishlist.dart';

import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';

import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
import 'package:get/get.dart';

class WishlistPage extends StatelessWidget {
  WishlistPage({super.key});

  final WishlistController _wishlistController = Get.find<WishlistController>();
  final UserController _userController = Get.find<UserController>();
  final CartController _cartController = Get.find<CartController>();

  @override
  Widget build(BuildContext context) {
    print(
      '≡ƒÅá WishlistPage built - User logged in: ${_userController.isLoggedIn}',
    );
    print(
      '≡ƒÅá WishlistPage built - Item count: ${_wishlistController.wishlistItemCount}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Obx(() {
          print(
            '≡ƒöä WishlistPage Obx rebuilding - Loading: ${_wishlistController.isLoading}',
          );
          print(
            '≡ƒöä WishlistPage Obx rebuilding - Error: ${_wishlistController.error}',
          );
          print(
            '≡ƒöä WishlistPage Obx rebuilding - Item count: ${_wishlistController.wishlistItemCount}',
          );

          if (!_userController.isLoggedIn) {
            print('≡ƒöÆ User not logged in, showing login required');
            return _buildLoginRequired();
          }

          if (_wishlistController.isLoading.value) {
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => MenuItemCardShimmer(),
            );
          }

          if (_wishlistController.error.isNotEmpty) {
            print('Γ¥î Wishlist error: ${_wishlistController.error}');
            return _buildErrorState();
          }

          if (_wishlistController.wishlistItemCount == 0) {
            print('≡ƒô¡ Wishlist is empty');
            return _buildEmptyWishlist();
          }

          print(
            'Γ£à Displaying ${_wishlistController.wishlistItemCount} wishlist items',
          );
          return _buildWishlistItems();
        }),
      ),
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

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: wishlist.items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final items = wishlist.items;
        if (index >= items.length) return const SizedBox.shrink();

        return FadeSlideIn(
          duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 200)),
          child: _buildWishlistItemCard(context, items[index]),
        );
      },
    );
  }

  Widget _buildWishlistItemCard(
    BuildContext context,
    WishlistItem wishlistItem,
  ) {
    final menuItem = wishlistItem.menuItem;
    final bool hasPromotion = menuItem.hasActivePromotions;
    final String priceText = hasPromotion
        ? menuItem.formattedDiscountedPrice
        : menuItem.formattedPrice;
    final String? originalPriceText = hasPromotion
        ? menuItem.formattedPrice
        : null;

    return _PressScale(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, top: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.of(context).push(
                SmoothPageRoute(
                  page: MenuItemDetailPage(menuItemId: menuItem.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipOval(
                              child: menuItem.imageUrl != null &&
                                      menuItem.imageUrl!.isNotEmpty
                                  ? CachedImage(
                                      imageUrl: menuItem.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholderIcon: Icons.fastfood,
                                    )
                                  : Icon(
                                      Icons.fastfood,
                                      color: Colors.grey[400],
                                    ),
                            ),
                          ),
                          if (hasPromotion)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  menuItem.activePromotions.first.formattedDiscount,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        menuItem.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TColor.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Column(
                        children: [
                          Text(
                            priceText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  hasPromotion ? Colors.red : TColor.primary,
                            ),
                          ),
                          if (originalPriceText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              originalPriceText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                Positioned(
                  top: -8,
                  left: -8,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () {
                      _wishlistController.removeFromWishlist(
                        menuItemId: menuItem.id,
                        accessToken: _userController.accessToken,
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildAddButton(menuItem)),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(MenuItem menuItem) {
    return Obx(() {
      final isInCart = _cartController.isItemInCart(menuItem.id);
      final isEnabled =
          _userController.isLoggedIn &&
          menuItem.isAvailable &&
          !_cartController.isItemProcessing('${menuItem.id}_add');

      if (isInCart) {
        return QuantityCounter(
          cartController: _cartController,
          menuItem: menuItem,
          accessToken: _userController.isLoggedIn
              ? _userController.accessToken
              : null,
          userId: _userController.user?.id,
          height: 32,
          compact: true,
        );
      }

      return SizedBox(
        width: 40,
        height: 40,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? TColor.primary : Colors.grey[300],
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 2,
          ),
          onPressed: isEnabled
              ? () async {
                  await _cartController.addToCart(
                    menuItem: menuItem,
                    quantity: 1,
                    accessToken: _userController.accessToken,
                    userId: _userController.user?.id,
                  );
                }
              : null,
          child: Icon(
            Icons.add,
            size: 20,
            color: isEnabled ? Colors.white : Colors.grey[500],
          ),
        ),
      );
    });
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

class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
