import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';

import 'package:get/get.dart';
// Use an alias to resolve the import conflict
import 'package:food_delivery_customer_app/controller/menu_controller.dart'
    as custom_menu;

import 'package:intl/intl.dart';

class MenuItemDetailPage extends StatefulWidget {
  final int menuItemId;

  const MenuItemDetailPage({super.key, required this.menuItemId});

  @override
  State<MenuItemDetailPage> createState() => _MenuItemDetailPageState();
}

class _MenuItemDetailPageState extends State<MenuItemDetailPage> {
  final custom_menu.MenuItemController menuController =
      Get.find<custom_menu.MenuItemController>();
  final CartController cartController = Get.find<CartController>();
  final UserController userController = Get.find<UserController>();
  final WishlistController wishlistController = Get.find<WishlistController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      menuController.getMenuItemDetail(widget.menuItemId);
    });
  }

  @override
  void dispose() {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        if (menuController.isLoadingDetail.value) {
          return _buildLoadingState();
        }

        final menuItem = menuController.selectedMenuItem.value;
        if (menuItem == null) {
          return _buildErrorState('Menu item not found');
        }

        return CustomScrollView(
          slivers: [
            // App Bar with Menu Item Image
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.white,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: TColor.primary),
                  onPressed: () {
                    // Close any open snackbars before navigating
                    if (Get.isSnackbarOpen == true) {
                      Get.closeAllSnackbars();
                    }
                    // Use Navigator instead of Get.back() to avoid GetX navigation conflicts
                    Navigator.of(context).pop();
                  },
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Obx(() {
                    final isInWishlist = wishlistController.isItemInWishlist(
                      menuItem.id,
                    );
                    return IconButton(
                      icon: Icon(
                        isInWishlist ? Icons.favorite : Icons.favorite_border,
                        color: isInWishlist ? Colors.red : TColor.primary,
                      ),
                      onPressed: () {
                        if (userController.isLoggedIn) {
                          wishlistController.toggleWishlist(
                            menuItem: menuItem,
                            accessToken: userController.accessToken,
                          );
                        } else {
                          Get.snackbar(
                            'Login Required',
                            'Please login to add items to wishlist',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.orange,
                            colorText: Colors.white,
                          );
                        }
                      },
                    );
                  }),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Menu Item Image
                    (menuItem.imageUrl ?? '').isNotEmpty
                        ? Image.network(menuItem.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.fastfood,
                              color: Colors.grey[500],
                              size: 80,
                            ),
                          ),

                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),

                    // Promotion Badge
                    if (menuItem.hasActivePromotions)
                      Positioned(
                        top: 60,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${menuItem.activePromotions.first.formattedDiscount} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Item Name and Price Overlay
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Item Title
                          Text(
                            menuItem.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Price Row
                          Row(
                            children: [
                              if (menuItem.hasActivePromotions) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TColor.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    menuItem.formattedDiscountedPrice,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  menuItem.formattedPrice,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.7),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.white.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TColor.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    menuItem.formattedPrice,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              // Dietary Info Badge
                              if ((menuItem.dietaryInfo ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    menuItem.dietaryInfo!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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

            // Menu Item Info
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 60,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Promotion Information
                      if (menuItem.hasActivePromotions)
                        _buildPromotionInfo(menuItem),

                      if (menuItem.hasActivePromotions)
                        const SizedBox(height: 16),

                      // Description
                      if (menuItem.description != null &&
                          menuItem.description!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: TColor.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              menuItem.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // Item Information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: TColor.primaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Availability',
                              menuItem.isAvailable
                                  ? 'Available'
                                  : 'Not Available',
                            ),
                            if (menuItem.prepTimeMinutes != null)
                              _buildInfoRow(
                                'Preparation Time',
                                '${menuItem.prepTimeMinutes} mins',
                              ),
                            _buildInfoRow(
                              'Category',
                              menuItem.categoryName ??
                                  'Category ${menuItem.category}',
                            ),
                            if (menuItem.allergens?.isNotEmpty ?? false)
                              _buildInfoRow('Allergens', menuItem.allergens!),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TColor.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          // Update your onPressed handler in the Add to Cart button:
                          onPressed: menuItem.isAvailable
                              ? () async {
                                  if (cartController.isItemInCart(menuItem.id))
                                    return;

                                  try {
                                    // Add a small delay to ensure smooth UI transition
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );

                                    await cartController.addToCart(
                                      menuItem: menuItem,
                                      quantity: 1,
                                      accessToken: userController.accessToken,
                                    );
                                  } catch (e) {
                                    // Error is handled by CartController via SnackbarService
                                  }
                                }
                              : null,
                          child: Obx(() {
                            final isAddingItem = cartController
                                .isItemProcessing('${menuItem.id}_add');

                            final isInCart = cartController.isItemInCart(
                              menuItem.id,
                            );

                            String buttonText;
                            if (!menuItem.isAvailable) {
                              buttonText = 'Not Available';
                            } else if (isInCart) {
                              buttonText = 'Already added to cart';
                            } else {
                              buttonText = menuItem.hasActivePromotions
                                  ? 'Add to Cart - ${menuItem.formattedDiscountedPrice}'
                                  : 'Add to Cart - ${menuItem.formattedPrice}';
                            }

                            return isAddingItem
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    buttonText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isInCart
                                          ? Colors.white70
                                          : Colors.white,
                                    ),
                                  );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPromotionInfo(MenuItem menuItem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TColor.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TColor.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔥 Special Offer',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ...menuItem.activePromotions
              .map(
                (promotion) => Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: TColor.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            promotion.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          promotion.formattedDiscount,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: TColor.primary,
                          ),
                        ),
                      ],
                    ),
                    if (promotion.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        promotion.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Valid until: ${DateFormat('MMM dd, yyyy').format(promotion.endDate.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: TColor.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: TColor.primary),
          const SizedBox(height: 16),
          Text(
            'Loading menu item...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              menuController.getMenuItemDetail(widget.menuItemId);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
