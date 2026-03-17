import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/location_controller.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/views/screens/confirm_order.dart';
import 'package:food_delivery_customer_app/views/screens/location_selection.dart';
import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class PaymentSelectionScreen extends StatefulWidget {
  const PaymentSelectionScreen({super.key});

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  final CartController _cartController = Get.find<CartController>();
  final LocationController _locationController = Get.find<LocationController>();
  final OrderController _orderController = Get.find<OrderController>();
  final UserController _userController = Get.find<UserController>();

  String _selectedPaymentMethod = 'cash'; // 'cash' or 'payment'
  String? _selectedMomoProvider; // Only shown when 'payment' is selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Checkout', style: ResponsiveText.heading2(context)),
        backgroundColor: Colors.white,
        foregroundColor: TColor.primaryText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Methods Section
                    FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Method',
                            style: ResponsiveText.heading3(context),
                          ),
                          const SizedBox(height: 16),
                          _buildPaymentMethodCard(
                            icon: Icons.money,
                            title: 'Cash on Delivery',
                            value: 'cash',
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodCard(
                            icon: Icons.payment,
                            title: 'Mobile Money / Card',
                            value: 'payment',
                          ),

                          // Momo provider selection (shown only when 'payment' is selected)
                          if (_selectedPaymentMethod == 'payment') ...[
                            const SizedBox(height: 16),
                            Text(
                              'Select Provider',
                              style: ResponsiveText.body(
                                context,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMomoProviderCard(
                              icon: Icons.phone_android,
                              title: 'MTN Mobile Money',
                              provider: 'mtn',
                              color: Colors.yellow[700]!,
                            ),
                            const SizedBox(height: 8),
                            _buildMomoProviderCard(
                              icon: Icons.phone_android,
                              title: 'Airtel Money',
                              provider: 'airtel',
                              color: Colors.red[700]!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Delivery Location Section
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Address',
                            style: ResponsiveText.heading3(context),
                          ),
                          const SizedBox(height: 12),
                          _buildDeliveryLocationButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Order Summary Section
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Summary',
                            style: ResponsiveText.heading3(context),
                          ),
                          const SizedBox(height: 12),
                          _buildOrderSummary(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: _buildActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
          if (value == 'cash') {
            _selectedMomoProvider = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? TColor.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: TColor.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? TColor.primary.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? TColor.primary : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? TColor.primary : TColor.primaryText,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              onChanged: (val) {
                setState(() {
                  _selectedPaymentMethod = val!;
                  if (val == 'cash') {
                    _selectedMomoProvider = null;
                  }
                });
              },
              activeColor: TColor.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomoProviderCard({
    required IconData icon,
    required String title,
    required String provider,
    required Color color,
  }) {
    final isSelected = _selectedMomoProvider == provider;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMomoProvider = provider;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TColor.primaryText,
                ),
              ),
            ),
            Radio<String>(
              value: provider,
              groupValue: _selectedMomoProvider,
              onChanged: (val) {
                setState(() {
                  _selectedMomoProvider = val;
                });
              },
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.all(16),
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
                      maxLines: 2,
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

  Widget _buildOrderSummary() {
    return Obx(() {
      if (_cartController.cart == null) {
        return const SizedBox();
      }

      // Calculate totals
      double originalSubtotal = 0.0;
      double discountedSubtotal = 0.0;
      double totalSavings = 0.0;

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
        }
      }

      final totalAmount = discountedSubtotal;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            _buildSummaryRow(
              'Order Amount',
              CurrencyFormatter.format(discountedSubtotal),
            ),
            if (totalSavings > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Promo Discount',
                '-${CurrencyFormatter.format(totalSavings)}',
                valueColor: Colors.green,
              ),
            ],
            Divider(height: 24, color: Colors.grey[300]),
            _buildSummaryRow(
              'Total Amount',
              CurrencyFormatter.format(totalAmount),
              isTotal: true,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: TColor.primaryText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color:
                valueColor ?? (isTotal ? TColor.primary : TColor.primaryText),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Obx(() {
      final hasLocation = _locationController.selectedLocation != null;
      final hasItems = _cartController.hasItems;
      final isProcessing = _orderController.isLoading.value;

      // Validate payment selection
      final paymentValid =
          _selectedPaymentMethod == 'cash' ||
          (_selectedPaymentMethod == 'payment' &&
              _selectedMomoProvider != null);

      String buttonText;
      bool isEnabled = false;

      if (!hasItems) {
        buttonText = 'Cart is Empty';
      } else if (!hasLocation) {
        buttonText = 'Select Delivery Location';
      } else if (!paymentValid) {
        buttonText = 'Select Payment Provider';
      } else if (isProcessing) {
        buttonText = 'Processing...';
      } else {
        buttonText = _selectedPaymentMethod == 'cash'
            ? 'Place Order'
            : 'Pay Now';
        isEnabled = true;
      }

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? TColor.primary : Colors.grey[400],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isEnabled ? 2 : 0,
          ),
          onPressed: isEnabled ? () => _placeOrder() : null,
          child: isProcessing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    });
  }

  Future<void> _placeOrder() async {
    try {
      final location = _locationController.selectedLocation;
      if (location == null) return;

      final cart = _cartController.cart;
      if (cart == null) return;

      // Determine payment method string for backend
      String paymentMethod = _selectedPaymentMethod;
      if (_selectedPaymentMethod == 'payment' &&
          _selectedMomoProvider != null) {
        paymentMethod = 'momo_$_selectedMomoProvider';
      }

      // Create order
      final order = await _orderController.createOrderFromCart(
        cartId: cart.id.toString(),
        deliveryAddress: location.address ?? 'Unknown address',
        deliveryLocation: location,
        paymentMethod: paymentMethod,
      );

      if (order != null) {
        // Navigate to order confirmation
        Get.off(() => OrderConfirmationPage(order: order));
      }
    } catch (e) {
      print('Error placing order: $e');
      // Error is already shown by the controller
    }
  }
}
