import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
import 'package:get/get.dart';

/// A reusable, distinctive menu-item card matching the home-screen blob style.
///
/// Used on the All Menu Items, Category, and other browsing screens to keep
/// a consistent visual identity.
class MenuItemCard extends StatefulWidget {
  final MenuItem menuItem;
  final bool showWishlist;
  final double width;
  final double? aspectRatio;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    this.showWishlist = true,
    this.width = 160,
    this.aspectRatio,
  });

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  static const List<Color> _fallbackAccents = [
    Color(0xFFFFF3E0),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFFFFDE7),
  ];

  Color _getAccentColor(int index) {
    return _fallbackAccents[index % _fallbackAccents.length];
  }

  String _resolveImageUrl(MenuItem item) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) return item.imageUrl!;
    if (item.images.isNotEmpty && item.images.first.imageUrl.isNotEmpty) {
      return item.images.first.imageUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final CartController cartController = Get.find();
    final UserController userController = Get.find();
    final WishlistController wishlistController = Get.find();

    final item = widget.menuItem;
    final imageUrl = _resolveImageUrl(item);
    final accentColor = _getAccentColor(item.id);
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText = hasPromotion
        ? item.formattedDiscountedPrice
        : item.formattedPrice;
    final String? originalPriceText = hasPromotion ? item.formattedPrice : null;

    return GestureDetector(
      onTap: () => Get.to(() => MenuItemDetailPage(menuItemId: item.id)),
      child: Container(
        width: widget.width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card body — color from accent
            Positioned(
              top: 42,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withAlpha(80),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 46, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        item.title,
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
                      // Price block
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            priceText,
                            style: TextStyle(
                              fontSize: hasPromotion ? 15 : 14,
                              fontWeight: FontWeight.w800,
                              color: hasPromotion
                                  ? const Color(0xFFE53935)
                                  : TColor.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (originalPriceText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              originalPriceText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Add to cart button
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
                ),
              ),
            ),

            // Floating circular food image
            Positioned(
              top: 0,
              left: widget.width / 2 - 42,
              child: Container(
                width: 84,
                height: 84,
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
                          width: 84,
                          height: 84,
                          placeholderIcon: Icons.fastfood,
                        )
                      : Container(
                          color: accentColor.withAlpha(60),
                          child: Center(
                            child: Icon(
                              Icons.fastfood_rounded,
                              size: 30,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Promo badge
            if (hasPromotion)
              Positioned(
                top: 0,
                right: 8,
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
            if (widget.showWishlist)
              Positioned(
                top: 0,
                left: 8,
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
}
