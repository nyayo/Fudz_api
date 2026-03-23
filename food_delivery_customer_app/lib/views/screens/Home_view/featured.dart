import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:get/get.dart';

class MenuItemsWidget extends StatefulWidget {
  const MenuItemsWidget({super.key});

  @override
  State<MenuItemsWidget> createState() => _MenuItemsWidgetState();
}

class _MenuItemsWidgetState extends State<MenuItemsWidget> {
  late ScrollController _scrollController;
  static const double _sectionInset = 16;

  static const List<Color> _fallbackAccents = [
    Color(0xFFFFF3E0),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFFFFDE7),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getAccentColor(int index, String imageUrl) {
    return _fallbackAccents[index % _fallbackAccents.length];
  }

  @override
  Widget build(BuildContext context) {
    final RestaurantController restaurantController = Get.find();
    final CartController cartController = Get.find();
    final UserController userController = Get.find();
    final WishlistController wishlistController = Get.find();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sectionInset),
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
                onTap: () => Get.to(() => AllMenuItemsPage()),
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
        const SizedBox(height: 16),
        Obx(() {
          if (restaurantController.isLoadingMenuItems.value) {
            return _buildLoadingWidget();
          }
          if (restaurantController.error.value.isNotEmpty) {
            return _buildErrorWidget();
          }
          final displayItems = restaurantController.menuItems.take(8).toList();
          if (displayItems.isEmpty) {
            return _buildEmptyWidget();
          }

          return SizedBox(
            height: 230,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: _sectionInset,
                right: _sectionInset,
                bottom: 8,
              ),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return _buildAnimatedCard(
                  index,
                  item,
                  cartController,
                  userController,
                  wishlistController,
                );
              },
            ),
          );
        }),
      ],
    );
  }

  String _resolveImageUrl(dynamic item) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return item.imageUrl!;
    }
    if (item.images != null &&
        item.images.isNotEmpty &&
        item.images.first.imageUrl.isNotEmpty) {
      return item.images.first.imageUrl;
    }
    if (item.image != null && item.image.isNotEmpty) return item.image;
    return '';
  }

  Widget _buildAnimatedCard(
    int index,
    dynamic item,
    CartController cartController,
    UserController userController,
    WishlistController wishlistController,
  ) {
    return _buildBlobCard(
      index,
      item,
      cartController,
      userController,
      wishlistController,
    );
  }

  Widget _buildBlobCard(
    int index,
    dynamic item,
    CartController cartController,
    UserController userController,
    WishlistController wishlistController,
  ) {
    final imageUrl = _resolveImageUrl(item);
    final String title = item.title?.toString() ?? 'Unknown Item';
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText = hasPromotion
        ? item.formattedDiscountedPrice
        : item.formattedPrice;
    final String? originalPriceText = hasPromotion ? item.formattedPrice : null;
    final accentColor = _getAccentColor(index, imageUrl);

    return GestureDetector(
      onTap: () => Get.to(() => MenuItemDetailPage(menuItemId: item.id)),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card body ΓÇö color from dominant image color
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withAlpha(120),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: TColor.primaryText,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Price row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  priceText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: hasPromotion
                                        ? const Color(0xFFE53935)
                                        : TColor.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Add to cart button with quantity counter
                          QuantityCounter(
                            cartController: cartController,
                            menuItem: item,
                            accessToken: userController.isLoggedIn
                                ? userController.accessToken
                                : null,
                            userId: userController.user?.id,
                            height: 32,
                            compact: true,
                          ),
                        ],
                      ),
                      if (originalPriceText != null)
                        Positioned(
                          right: 0,
                          top: 30,
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Text(
                              originalPriceText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating circular food image ΓÇö pops on top, ring color from image
            Positioned(
              top: 0,
              left: 160 / 2 - 48,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: accentColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? CachedImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                          placeholderIcon: Icons.fastfood,
                        )
                      : _buildPlaceholderIcon(accentColor),
                ),
              ),
            ),

            // Promo badge
            if (hasPromotion)
              Positioned(
                top: 2,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
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
                    ),
                  ),
                ),
              ),

            // Wishlist heart
            Positioned(
              top: 2,
              left: 10,
              child: Obx(() {
                final isInWishlist = wishlistController.isItemInWishlist(
                  item.id,
                );
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
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 6,
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
                      size: 14,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(Color accent) {
    return Container(
      color: accent.withAlpha(60),
      child: Center(
        child: Icon(Icons.fastfood_rounded, size: 34, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 160 / 2 - 48,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: Colors.grey[400],
            ),
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
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_rounded, size: 36, color: Colors.grey[350]),
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
