import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:food_delivery_customer_app/views/screens/restaurant_details.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/controller/menu_controller.dart'
    as custom_menu;

import 'package:intl/intl.dart';

class MenuItemDetailPage extends StatefulWidget {
  final int menuItemId;

  const MenuItemDetailPage({super.key, required this.menuItemId});

  @override
  State<MenuItemDetailPage> createState() => _MenuItemDetailPageState();
}

class _MenuItemDetailPageState extends State<MenuItemDetailPage>
    with SingleTickerProviderStateMixin {
  final custom_menu.MenuItemController menuController =
      Get.find<custom_menu.MenuItemController>();
  final CartController cartController = Get.find<CartController>();
  final UserController userController = Get.find<UserController>();
  final WishlistController wishlistController = Get.find<WishlistController>();
  final RestaurantController restaurantController =
      Get.find<RestaurantController>();

  int _quantity = 1;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await menuController.getMenuItemDetail(
        widget.menuItemId,
        forceRefresh: true,
      );
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Obx(() {
        if (menuController.isLoadingDetail.value) {
          return _buildLoadingState();
        }

        final menuItem = menuController.selectedMenuItem.value;
        if (menuItem == null) {
          return _buildErrorState('Menu item not found');
        }

        return Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildImageAppBar(menuItem),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildContent(menuItem),
                  ),
                ),
              ],
            ),
            // Floating bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(menuItem),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildImageAppBar(MenuItem menuItem) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: TColor.primary,
      leading: _buildCircleButton(
        icon: Icons.arrow_back,
        onPressed: () {
          if (Get.isSnackbarOpen == true) Get.closeAllSnackbars();
          Navigator.of(context).pop();
        },
      ),
      actions: [
        Obx(() {
          final isInWishlist = wishlistController.isItemInWishlist(menuItem.id);
          return _buildCircleButton(
            icon: isInWishlist ? Icons.favorite : Icons.favorite_border,
            color: isInWishlist ? Colors.red : Colors.white,
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
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Hero(
              tag: 'menu_item_${menuItem.id}',
              child: (menuItem.imageUrl ?? '').isNotEmpty
                  ? Image.network(menuItem.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.fastfood,
                        color: Colors.grey[500],
                        size: 80,
                      ),
                    ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Promotion badge
            if (menuItem.hasActivePromotions)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${menuItem.activePromotions.first.formattedDiscount} OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Bottom info on image
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category chip
                  if (menuItem.categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        menuItem.categoryName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    menuItem.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildContent(MenuItem menuItem) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price card
          _buildPriceCard(menuItem),
          const SizedBox(height: 16),

          // Restaurant info bar
          _buildRestaurantBar(menuItem),
          const SizedBox(height: 16),

          // Quick info chips
          _buildQuickInfoChips(menuItem),

          // Promotion info
          if (menuItem.hasActivePromotions) ...[
            const SizedBox(height: 16),
            _buildPromotionCard(menuItem),
          ],

          // Description
          if (menuItem.description != null &&
              menuItem.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDescriptionSection(menuItem),
          ],

          // Item details
          const SizedBox(height: 20),
          _buildDetailsSection(menuItem),
        ],
      ),
    );
  }

  Widget _buildPriceCard(MenuItem menuItem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              if (menuItem.hasActivePromotions) ...[
                Text(
                  menuItem.formattedDiscountedPrice,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: TColor.primary,
                  ),
                ),
                Text(
                  menuItem.formattedPrice,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.grey[400],
                  ),
                ),
              ] else
                Text(
                  menuItem.formattedPrice,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: TColor.primary,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Availability badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: menuItem.isAvailable
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  menuItem.isAvailable ? Icons.check_circle : Icons.cancel,
                  color: menuItem.isAvailable ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  menuItem.isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    color: menuItem.isAvailable ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantBar(MenuItem menuItem) {
    // Get restaurant rating from controller cache
    double? restaurantRating;
    String restaurantName =
        menuItem.restaurantName ?? menuItem.safeRestaurantName;

    // Try to get rating from cached restaurants
    final restaurants = restaurantController.restaurants;
    for (var r in restaurants) {
      if (r.id == menuItem.restaurantId) {
        restaurantRating = r.avgRating ?? r.rating;
        restaurantName = r.restaurantName.isNotEmpty
            ? r.restaurantName
            : restaurantName;
        break;
      }
    }

    return GestureDetector(
      onTap: () {
        if (menuItem.restaurantId != null) {
          Get.to(
            () => RestaurantDetailPage(restaurantId: menuItem.restaurantId!),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Restaurant icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.storefront, color: TColor.primary, size: 22),
            ),
            const SizedBox(width: 12),
            // Restaurant name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurantName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: TColor.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View restaurant',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Rating
            if (restaurantRating != null && restaurantRating > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      restaurantRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoChips(MenuItem menuItem) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (menuItem.prepTimeMinutes != null)
          _infoChip(
            Icons.access_time_filled,
            '${menuItem.prepTimeMinutes} min',
            Colors.blue,
          ),
        if ((menuItem.dietaryInfo ?? '').isNotEmpty)
          _infoChip(Icons.eco, menuItem.dietaryInfo!, Colors.green),
        if (menuItem.allergens?.isNotEmpty ?? false)
          _infoChip(
            Icons.warning_amber_rounded,
            menuItem.allergens!,
            Colors.orange,
          ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionCard(MenuItem menuItem) {
    final promo = menuItem.activePromotions.first;
    final savings = menuItem.price - menuItem.discountedPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE53935).withOpacity(0.04),
            const Color(0xFFE53935).withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Color(0xFFE53935),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: TColor.primaryText,
                      ),
                    ),
                    if (promo.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        promo.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${promo.formattedDiscount} OFF',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Price breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promo Price',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      menuItem.formattedDiscountedPrice,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: TColor.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      menuItem.formattedPrice,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save ${CurrencyFormatter.format(savings)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Expires ${DateFormat('MMM dd, yyyy').format(promo.endDate.toLocal())}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(MenuItem menuItem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'About this dish',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            menuItem.description!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(MenuItem menuItem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            Icons.category,
            'Category',
            menuItem.categoryName ?? 'Category ${menuItem.category}',
          ),
          if (menuItem.prepTimeMinutes != null)
            _buildDetailRow(
              Icons.timer_outlined,
              'Prep Time',
              '${menuItem.prepTimeMinutes} minutes',
            ),
          if ((menuItem.dietaryInfo ?? '').isNotEmpty)
            _buildDetailRow(Icons.eco, 'Dietary Info', menuItem.dietaryInfo!),
          if (menuItem.allergens?.isNotEmpty ?? false)
            _buildDetailRow(
              Icons.warning_amber,
              'Allergens',
              menuItem.allergens!,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[600], size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
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
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(MenuItem menuItem) {
    final hasPromo = menuItem.hasActivePromotions;
    final effectivePrice = hasPromo ? menuItem.discountedPrice : menuItem.price;
    final totalPrice = effectivePrice * _quantity;
    final savings = hasPromo
        ? (menuItem.price - menuItem.discountedPrice) * _quantity
        : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Savings banner
          if (hasPromo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You save ${CurrencyFormatter.format(savings)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${menuItem.activePromotions.first.formattedDiscount} OFF',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Quantity selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _quantityButton(Icons.remove, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$_quantity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TColor.primaryText,
                        ),
                      ),
                    ),
                    _quantityButton(Icons.add, () {
                      setState(() => _quantity++);
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Add to cart button
              Expanded(
                child: Obx(() {
                  final isAdding = cartController.isItemProcessing(
                    '${menuItem.id}_add',
                  );
                  final isInCart = cartController.isItemInCart(menuItem.id);

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInCart
                          ? Colors.grey[400]
                          : TColor.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: isInCart ? 0 : 2,
                    ),
                    onPressed: (!menuItem.isAvailable || isInCart)
                        ? null
                        : () async {
                            try {
                              await cartController.addToCart(
                                menuItem: menuItem,
                                quantity: _quantity,
                                accessToken: userController.accessToken,
                              );
                            } catch (_) {}
                          },
                    child: isAdding
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                !menuItem.isAvailable
                                    ? 'Unavailable'
                                    : isInCart
                                    ? 'In Cart'
                                    : 'Add to Cart',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (menuItem.isAvailable && !isInCart) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(totalPrice),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    if (hasPromo) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        CurrencyFormatter.format(
                                          menuItem.price * _quantity,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.6),
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: Colors.white
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: TColor.primaryText),
        ),
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
            onPressed: () =>
                menuController.getMenuItemDetail(widget.menuItemId),
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
