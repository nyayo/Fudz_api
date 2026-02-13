import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:get/get.dart';

class MenuItemsWidget extends StatefulWidget {
  const MenuItemsWidget({super.key});

  @override
  State<MenuItemsWidget> createState() => _MenuItemsWidgetState();
}

class _MenuItemsWidgetState extends State<MenuItemsWidget>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _titleController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleController.forward();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RestaurantController restaurantController = Get.find();
    final CartController cartController = Get.find();
    final UserController userController = Get.find();
    final WishlistController wishlistController = Get.find();

    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated title
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.3, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _titleController,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: _titleController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              TColor.primary,
                              TColor.primary.withAlpha(150),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Popular Menu Items',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: TColor.primaryText,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Get.to(() => AllMenuItemsPage());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TColor.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See all',
                            style: TextStyle(
                              color: TColor.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: TColor.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

          // Use a vertical list with 2-column grid style for menu items
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (displayItems.length / 2).ceil(),
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, rowIndex) {
              final firstIndex = rowIndex * 2;
              final secondIndex = firstIndex + 1;

              return Row(
                children: [
                  Expanded(
                    child: _buildAnimatedCard(
                      firstIndex,
                      displayItems[firstIndex],
                      cartController,
                      userController,
                      wishlistController,
                      screenWidth,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: secondIndex < displayItems.length
                        ? _buildAnimatedCard(
                            secondIndex,
                            displayItems[secondIndex],
                            cartController,
                            userController,
                            wishlistController,
                            screenWidth,
                          )
                        : const SizedBox(),
                  ),
                ],
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildAnimatedCard(
    int index,
    dynamic item,
    CartController cartController,
    UserController userController,
    WishlistController wishlistController,
    double screenWidth,
  ) {
    final delay = (index * 0.12).clamp(0.0, 0.6);
    final itemAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          delay,
          (delay + 0.4).clamp(0, 1),
          curve: Curves.easeOutBack,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - itemAnimation.value)),
          child: Transform.scale(
            scale: 0.85 + (0.15 * itemAnimation.value),
            child: Opacity(
              opacity: itemAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: _buildMenuItemCard(
        item,
        cartController,
        userController,
        wishlistController,
        screenWidth,
      ),
    );
  }

  Widget _buildMenuItemCard(
    dynamic item,
    CartController cartController,
    UserController userController,
    WishlistController wishlistController,
    double screenWidth,
  ) {
    String getImageUrl() {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        return item.imageUrl!;
      }
      if (item.images != null &&
          item.images.isNotEmpty &&
          item.images.first.imageUrl.isNotEmpty) {
        return item.images.first.imageUrl;
      }
      if (item.image != null && item.image.isNotEmpty) {
        return item.image;
      }
      return '';
    }

    final imageUrl = getImageUrl();
    final String title = item.title?.toString() ?? 'Unknown Item';
    final String description =
        item.description?.toString() ?? 'Delicious food item';
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText =
        hasPromotion ? item.formattedDiscountedPrice : item.formattedPrice;
    final String? originalPriceText =
        hasPromotion ? item.formattedPrice : null;

    return GestureDetector(
      onTap: () {
        Get.to(() => MenuItemDetailPage(menuItemId: item.id));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFFF5F5F5),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TColor.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(30),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Promotion badge
                    if (hasPromotion)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF5252),
                                Color(0xFFFF1744),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withAlpha(50),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${item.activePromotions.first.formattedDiscount} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    // Wishlist button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Obx(() {
                        final isInWishlist =
                            wishlistController.isItemInWishlist(item.id);
                        return GestureDetector(
                          onTap: () {
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
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isInWishlist
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isInWishlist
                                  ? const Color(0xFFFF5252)
                                  : Colors.grey[400],
                              size: 16,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TColor.primaryText,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Price row with add button
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: hasPromotion
                                    ? const Color(0xFFFF5252)
                                    : TColor.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (originalPriceText != null)
                              Text(
                                originalPriceText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.grey[400],
                                ),
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                      // Add to cart button
                      Obx(() {
                        final isProcessing =
                            cartController.isItemProcessing('${item.id}_add');
                        final isInCart =
                            cartController.isItemInCart(item.id);
                        return GestureDetector(
                          onTap: (isProcessing || isInCart)
                              ? null
                              : () async {
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
                                      accessToken:
                                          userController.accessToken,
                                    );
                                  } catch (e) {
                                    // Error handled by controller
                                  }
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: isInCart
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        TColor.primary,
                                        TColor.primary.withAlpha(200),
                                      ],
                                    ),
                              color: isInCart
                                  ? const Color(0xFFF5F5F5)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isInCart
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: TColor.primary.withAlpha(60),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: isProcessing
                                  ? SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation(
                                          isInCart
                                              ? Colors.grey
                                              : Colors.white,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      isInCart
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      color: isInCart
                                          ? Colors.grey[500]
                                          : Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 40,
          color: Colors.grey[350],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: Duration(milliseconds: 800 + (index * 200)),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 90,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 120,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 50,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius:
                                      BorderRadius.circular(12),
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
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Failed to load items',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_rounded,
                size: 36, color: Colors.grey[350]),
            const SizedBox(height: 8),
            Text(
              'No menu items available',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}