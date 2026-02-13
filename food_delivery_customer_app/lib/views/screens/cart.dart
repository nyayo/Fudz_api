import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/location_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/cart.dart';
import 'package:food_delivery_customer_app/views/screens/all_menu_items.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:food_delivery_customer_app/views/screens/location_selection.dart';
import 'package:food_delivery_customer_app/views/screens/payment_selection.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartController _cartController = Get.find<CartController>();
  final UserController _userController = Get.find<UserController>();
  final LocationController _locationController = Get.find<LocationController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userController.isLoggedIn && _cartController.cart == null) {
        _cartController.initializeCart(
          accessToken: _userController.accessToken,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                // top: 20,
                // bottom: 20,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Text('My Cart', style: ResponsiveText.heading2(context)),
                  const Spacer(),
                  Obx(() {
                    if (_cartController.hasItems) {
                      return TextButton(
                        onPressed: () => _showClearCartDialog(),
                        child: Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      );
                    }
                    return const SizedBox();
                  }),
                ],
              ),
            ),

            // Cart Content
            Obx(() {
              if (_cartController.isLoading.value) {
                return Expanded(
                  child: ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) => MenuItemCardShimmer(),
                  ),
                );
              }

              if (!_cartController.hasItems) {
                return _buildEmptyCart();
              }

              return _buildCartItems(media);
            }),

            // Order Summary
            Obx(() {
              if (!_cartController.hasItems) return const SizedBox();

              return FadeSlideIn(
                duration: const Duration(milliseconds: 500),
                child: _buildOrderSummary(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    var media = MediaQuery.of(context).size;

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeSlideIn(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: TColor.primary,
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              duration: const Duration(milliseconds: 300),
              delay: const Duration(milliseconds: 50),
              child: Text(
                'No items in cart',
                style: ResponsiveText.heading2(context),
              ),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              duration: const Duration(milliseconds: 300),
              delay: const Duration(milliseconds: 100),
              child: Text(
                'Your favorite foods are waiting!',
                style: ResponsiveText.body(context, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: media.width * 0.6,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Get.to(() => AllMenuItemsPage());
                },
                child: Builder(
                  builder: (context) => Text(
                    'Browse Menu',
                    style: ResponsiveText.button(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItems(Size media) {
    return Expanded(
      child: Obx(() {
        if (_cartController.cart == null) {
          return _buildEmptyCart();
        }

        // Sort items by menu item ID to maintain consistent order
        final sortedItems = List<CartItem>.from(_cartController.cart!.items)
          ..sort((a, b) => a.menuItem.id.compareTo(b.menuItem.id));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: sortedItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = sortedItems[index];
            return KeyedSubtree(
              key: ValueKey('cart_item_${item.menuItem.id}'),
              child: _buildCartItemCard(item, media),
            );
          },
        );
      }),
    );
  }

  Widget _buildCartItemCard(CartItem item, Size media) {
    final bool hasPromotion = item.menuItem.hasActivePromotions;
    final double originalPrice = item.menuItem.price;
    final double discountedPrice = item.menuItem.discountedPrice;
    final bool isDiscounted = hasPromotion && discountedPrice < originalPrice;
    final double itemPrice = isDiscounted ? discountedPrice : originalPrice;
    final double itemTotal = itemPrice * item.quantity;

    return Obx(() {
      final isProcessing =
          _cartController.isItemProcessing('${item.id}_update') ||
          _cartController.isItemProcessing('${item.id}_remove');

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDiscounted
              ? Border.all(color: Colors.red.withOpacity(0.2), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 0.5,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Discount badge (top-right corner)
            if (isDiscounted)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_calculateDiscountPercentage(originalPrice, discountedPrice)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Food Image - Centered
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Builder(
                      builder: (context) {
                        final imageUrl = item.menuItem.imageUrl;

                        if (imageUrl == null || imageUrl.isEmpty) {
                          return Center(
                            child: Icon(
                              Icons.fastfood,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          );
                        }

                        return Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 1.5,
                                color: TColor.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Food Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title and Restaurant name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.menuItem.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.menuItem.safeRestaurantName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price, quantity, and total section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price and total column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Unit price
                                Row(
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(itemPrice),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDiscounted
                                            ? Colors.red
                                            : TColor.primary,
                                      ),
                                    ),
                                    if (isDiscounted)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          CurrencyFormatter.format(
                                            originalPrice,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),

                                // Quantity × Price calculation
                                Row(
                                  children: [
                                    Text(
                                      '${item.quantity} × ${CurrencyFormatter.format(itemPrice)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Item total
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    // horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Item total: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(itemTotal),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: TColor.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Vertical quantity controls
                          Container(
                            width: 28,
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: TColor.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Plus button
                                SizedBox(
                                  height: 22,
                                  width: 28,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(9),
                                        topRight: Radius.circular(9),
                                      ),
                                      onTap: isProcessing
                                          ? null
                                          : () {
                                              _cartController.updateQuantity(
                                                itemId: item.id,
                                                quantity: item.quantity + 1,
                                                accessToken:
                                                    _userController.accessToken,
                                              );
                                            },
                                      child: Center(
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: isProcessing
                                              ? Colors.grey[400]
                                              : TColor.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Divider
                                Container(
                                  height: 1,
                                  width: 28,
                                  color: TColor.primary.withOpacity(0.2),
                                ),

                                // Quantity display
                                Container(
                                  height: 22,
                                  width: 28,
                                  color: Colors.white,
                                  child: Center(
                                    child: Text(
                                      item.quantity.toString(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: TColor.primaryText,
                                      ),
                                    ),
                                  ),
                                ),

                                // Divider
                                Container(
                                  height: 1,
                                  width: 28,
                                  color: TColor.primary.withOpacity(0.2),
                                ),

                                // Minus button
                                SizedBox(
                                  height: 22,
                                  width: 28,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(9),
                                        bottomRight: Radius.circular(9),
                                      ),
                                      onTap: isProcessing
                                          ? null
                                          : () {
                                              _cartController.updateQuantity(
                                                itemId: item.id,
                                                quantity: item.quantity - 1,
                                                accessToken:
                                                    _userController.accessToken,
                                              );
                                            },
                                      child: Center(
                                        child: Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: isProcessing
                                              ? Colors.grey[400]
                                              : TColor.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Processing overlay
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TColor.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  // Helper method to calculate discount percentage
  int _calculateDiscountPercentage(
    double originalPrice,
    double discountedPrice,
  ) {
    if (originalPrice <= 0) return 0;
    final discount = ((originalPrice - discountedPrice) / originalPrice) * 100;
    return discount.round();
  }

  Widget _buildOrderSummary() {
    final CartController cartController = Get.find();
    final UserController userController = Get.find();
    final LocationController locationController = Get.find();

    // Calculate both original and discounted totals
    double originalSubtotal = 0.0;
    double discountedSubtotal = 0.0;
    double totalSavings = 0.0;
    int totalDiscountedItems = 0;

    if (_cartController.cart != null) {
      for (final item in _cartController.cart!.items) {
        final originalPrice = item.menuItem.price;
        final discountedPrice = item.menuItem.discountedPrice;
        final isDiscounted = discountedPrice < originalPrice;

        final originalItemTotal = originalPrice * item.quantity;
        final discountedItemTotal = isDiscounted
            ? discountedPrice * item.quantity
            : originalItemTotal;

        originalSubtotal += originalItemTotal;
        discountedSubtotal += discountedItemTotal;

        if (isDiscounted) {
          totalSavings += (originalItemTotal - discountedItemTotal);
          totalDiscountedItems++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Final Total
          _buildSummaryRow(
            'Total',
            CurrencyFormatter.format(discountedSubtotal),
            isTotal: true,
          ),

          // Savings message
          if (totalSavings > 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'You saved ${CurrencyFormatter.format(totalSavings)} with promotions!',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Checkout Button
          Obx(() {
            final isLoggedIn = userController.isLoggedIn;
            final hasItems = _cartController.hasItems;
            final isCheckingOut = cartController.isCheckingOut.value;
            final hasLocation = locationController.selectedLocation != null;

            String buttonText;
            bool isEnabled = false;

            if (!isLoggedIn) {
              buttonText = 'Login to Checkout';
            } else if (!hasItems) {
              buttonText = 'Cart is Empty';
            } else {
              buttonText = isCheckingOut
                  ? 'Processing...'
                  : 'Proceed to Checkout';
              isEnabled = !isCheckingOut;
            }

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled
                      ? TColor.primary
                      : Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isEnabled ? 2 : 0,
                ),
                onPressed: isEnabled ? () => _proceedToCheckout() : null,
                child: isCheckingOut
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Delivery Location Button
  Widget _buildDeliveryLocationButton() {
    return GestureDetector(
      onTap: () async {
        final selectedLocation = await Get.to(
          () => const LocationSelectionScreen(),
        );
        if (selectedLocation != null) {
          _locationController.updateSelectedLocation(selectedLocation);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Obx(() {
                final hasLocation =
                    _locationController.selectedLocation != null;
                return Icon(
                  Icons.location_on,
                  color: hasLocation ? TColor.primary : Colors.grey,
                  size: 20,
                );
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() {
                final location = _locationController.selectedLocation;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery location",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location?.address ?? "Tap to set delivery location",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: location != null
                            ? TColor.primaryText
                            : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: TColor.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
    bool isBold = false,
    bool showStrikethrough = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal || isBold
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isTotal ? TColor.primaryText : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal || isBold
                  ? FontWeight.bold
                  : FontWeight.normal,
              color:
                  valueColor ?? (isTotal ? TColor.primary : Colors.grey[600]),
              decoration: showStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to clear all items from your cart?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _cartController.clearCart(
                accessToken: _userController.accessToken,
              );
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    // Navigate to payment selection screen
    Get.to(() => const PaymentSelectionScreen());
  }
}

// Simple order confirmation page
class OrderConfirmationPage extends StatelessWidget {
  final Order order;

  const OrderConfirmationPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmed')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: TColor.primary, size: 80),
            const SizedBox(height: 20),
            Text(
              'Order #${order.id}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: TColor.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your order has been placed successfully!',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Get.toNamed('/home');
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
