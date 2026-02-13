import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:get/get.dart';

class MenuItemsWidget extends StatelessWidget {
  const MenuItemsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final RestaurantController restaurantController = Get.find();
    final CartController cartController = Get.find();
    final UserController userController = Get.find();
    final WishlistController wishlistController = Get.find();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = (screenWidth * 0.32).clamp(180.0, 220.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Popular Menu Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TColor.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Get.to(() => AllMenuItemsPage());
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: TColor.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (restaurantController.isLoadingMenuItems.value) {
            return _buildLoadingWidget();
          }

          if (restaurantController.error.value.isNotEmpty) {
            return _buildErrorWidget(restaurantController.error.value);
          }

          final displayItems = restaurantController.menuItems.take(6).toList();

          if (displayItems.isEmpty) {
            return _buildEmptyWidget();
          }

          return SizedBox(
            height: screenHeight * 0.28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: displayItems.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _buildMenuItemCard(
                  item,
                  cartController,
                  userController,
                  wishlistController,
                  cardWidth,
                  screenHeight * 0.26,
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: TColor.primary),
            const SizedBox(height: 16),
            Text(
              'Loading menu items...',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Failed to load items',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No menu items available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(
    dynamic item,
    CartController cartController,
    UserController userController,
    WishlistController wishlistController,
    double cardWidth,
    double listHeight,
  ) {
    String getImageUrl() {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        return item.imageUrl!;
      }
      if (item.images != null && item.images.isNotEmpty && item.images.first.imageUrl.isNotEmpty) {
        return item.images.first.imageUrl;
      }
      if (item.image != null && item.image.isNotEmpty) {
        return item.image;
      }
      return '';
    }

    final imageUrl = getImageUrl();
    final imageHeight = listHeight * 0.45;
    final contentPadding = cardWidth * 0.05;

    final String title = item.title?.toString() ?? 'Unknown Item';
    final String description = item.description?.toString() ?? 'Delicious food item';
    
    // Use discounted price if there's an active promotion
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText = hasPromotion 
        ? item.formattedDiscountedPrice 
        : item.formattedPrice;
    final String? originalPriceText = hasPromotion ? item.formattedPrice : null;

    return SizedBox(
      width: cardWidth,
      child: GestureDetector(
        onTap: () {
          Get.to(() => MenuItemDetailPage(menuItemId: item.id));
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image
              Container(
                height: imageHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Item Image
                    imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: imageHeight,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: TColor.primary,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderIcon(imageHeight);
                              },
                            ),
                          )
                        : _buildPlaceholderIcon(imageHeight),
                    
                    // Promotion Badge
                    if (hasPromotion)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${item.activePromotions.first.formattedDiscount} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    
                    // Wishlist Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Obx(() {
                        final isInWishlist = wishlistController.isItemInWishlist(item.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isInWishlist ? Icons.favorite : Icons.favorite_border,
                              color: isInWishlist ? Colors.red : TColor.primary,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: cardWidth * 0.16,
                              minHeight: cardWidth * 0.16,
                            ),
                            onPressed: () {
                              if (userController.isLoggedIn) {
                                wishlistController.toggleWishlist(
                                  menuItem: item,
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
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              // Item Details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding.clamp(8.0, 12.0)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title and Description
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: (cardWidth * 0.07).clamp(13.0, 16.0),
                                fontWeight: FontWeight.bold,
                                color: TColor.primaryText,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: contentPadding * 0.3),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: (cardWidth * 0.055).clamp(10.0, 12.0),
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Price and Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  priceText,
                                  style: TextStyle(
                                    fontSize: (cardWidth * 0.075).clamp(14.0, 16.0),
                                    fontWeight: FontWeight.bold,
                                    color: hasPromotion ? Colors.red : TColor.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (originalPriceText != null)
                                  Text(
                                    originalPriceText,
                                    style: TextStyle(
                                      fontSize: (cardWidth * 0.055).clamp(10.0, 12.0),
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Add Button
                          Container(
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Obx(() {
                              final isProcessing = cartController.isItemProcessing('${item.id}_add');
                              final isInCart = cartController.isItemInCart(item.id);
                              
                              return IconButton(
                                icon: isProcessing
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(TColor.primary),
                                        ),
                                      )
                                    : Icon(
                                        isInCart ? Icons.check_circle : Icons.add_circle,
                                        color: isInCart ? Colors.grey : TColor.primary,
                                        size: (cardWidth * 0.10).clamp(18.0, 24.0),
                                      ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: cardWidth * 0.16,
                                  minHeight: cardWidth * 0.16,
                                ),
                                onPressed: (isProcessing || isInCart)
                                    ? null
                                    : () async {
                                        final userController = Get.find<UserController>();
                                        if (!userController.isLoggedIn) {
                                          Get.snackbar(
                                            'Login Required',
                                            'Please login to add items to cart',
                                            snackPosition: SnackPosition.TOP,
                                            backgroundColor: Colors.orange,
                                            colorText: Colors.white,
                                          );
                                          return;
                                        }

                                        try {
                                          await cartController.addToCart(
                                            menuItem: item,
                                            quantity: 1,
                                            accessToken: userController.accessToken,
                                          );
                                        } catch (e) {
                                          // Error handled by controller
                                        }
                                      },
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: Colors.grey[300],
      ),
      child: Center(
        child: Icon(
          Icons.fastfood,
          size: height * 0.35,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}