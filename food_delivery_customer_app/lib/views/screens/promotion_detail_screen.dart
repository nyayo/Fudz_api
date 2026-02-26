import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/promo.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:get/get.dart';

class PromotionDetailScreen extends StatelessWidget {
  final Promotion promotion;
  final List<MenuItem> items;

  const PromotionDetailScreen({
    super.key,
    required this.promotion,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final daysRemaining = promotion.endDate.difference(DateTime.now()).inDays;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero banner
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: TColor.primary,
            leading: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner image or gradient
                  if (promotion.hasBanner)
                    CachedImage(
                      imageUrl: promotion.banner,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.local_offer,
                    )
                  else
                    _buildGradientBanner(),

                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),

                  // Content on banner
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discount badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${promotion.formattedDiscount} OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          promotion.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (promotion.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            promotion.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Items count
                  _buildInfoChip(
                    Icons.restaurant_menu_rounded,
                    '${items.length} items',
                  ),
                  const SizedBox(width: 16),
                  // Days remaining
                  if (daysRemaining > 0)
                    _buildInfoChip(
                      Icons.timer_outlined,
                      daysRemaining == 1
                          ? '1 day left'
                          : '$daysRemaining days left',
                      color: daysRemaining <= 3 ? Colors.red : Colors.orange,
                    ),
                  const Spacer(),
                  // Discount
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TColor.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      promotion.formattedDiscount,
                      style: TextStyle(
                        color: TColor.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: TColor.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Items in this promotion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TColor.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return _PromotionItemCard(item: item, promotion: promotion);
              }, childCount: items.length),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildGradientBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TColor.primary,
            TColor.primary.withOpacity(0.7),
            const Color(0xFF2E7D32),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 80,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color ?? Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PromotionItemCard extends StatelessWidget {
  final MenuItem item;
  final Promotion promotion;

  const _PromotionItemCard({required this.item, required this.promotion});

  @override
  Widget build(BuildContext context) {
    final originalPrice = item.price;
    final discountedPrice = originalPrice * (1 - promotion.discount / 100);

    return GestureDetector(
      onTap: () => Get.to(() => MenuItemDetailPage(menuItemId: item.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: item.hasImage
                    ? Image.network(
                        item.safeImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TColor.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.safeDescription.isNotEmpty &&
                      item.safeDescription != 'No description available')
                    Text(
                      item.safeDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Price row
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          CurrencyFormatter.format(discountedPrice),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: TColor.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          CurrencyFormatter.format(originalPrice),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[400],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Discount badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${promotion.formattedDiscount}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Add to cart button
            _AddToCartButton(item: item),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Icon(Icons.fastfood_rounded, color: Colors.grey[300], size: 36),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  final MenuItem item;

  const _AddToCartButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final userController = Get.find<UserController>();

    return QuantityCounter(
      cartController: cartController,
      menuItem: item,
      accessToken: userController.isLoggedIn
          ? userController.accessToken
          : null,
      height: 40,
      compact: true,
    );
  }
}
