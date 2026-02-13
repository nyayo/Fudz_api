import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/models/cart.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';

import 'package:get/get.dart';

class OrderConfirmationPage extends StatelessWidget {
  final Order order;

  const OrderConfirmationPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: Colors.white,
        foregroundColor: TColor.primaryText,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScalePopIn(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              child: Icon(Icons.check_circle, color: TColor.primary, size: 80),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Text(
                'Order #${order.id}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: const Duration(milliseconds: 450),
              child: Text(
                'Your order has been placed successfully!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),

            // Show delivery location
            FadeSlideIn(
              delay: const Duration(milliseconds: 600),
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery to:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: TColor.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.displayDeliveryAddress,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            ),

            const Spacer(),
            FadeSlideIn(
              delay: const Duration(milliseconds: 750),
              slideOffset: const Offset(0, 0.2),
              child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Get.offAllNamed('/home');
                },
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
