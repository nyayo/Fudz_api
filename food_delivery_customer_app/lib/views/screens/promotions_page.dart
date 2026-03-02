import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/promotion_controller.dart';
import 'package:food_delivery_customer_app/models/promo.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PromotionController _promotionController =
      Get.find<PromotionController>();

  @override
  void initState() {
    super.initState();
    // Refresh promotions when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promotionController.refreshPromotions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        backgroundColor: TColor.primary,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (_promotionController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_promotionController.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _promotionController.error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _promotionController.refreshPromotions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final activePromotions = _promotionController.activePromotions;

        if (activePromotions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active promotions available',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _promotionController.refreshPromotions,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activePromotions.length,
            itemBuilder: (context, index) {
              final promotion = activePromotions[index];
              return AnimatedListItem(
                index: index,
                child: _buildPromotionCard(promotion),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    final daysRemaining = promotion.endDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              TColor.primary.withOpacity(0.1),
              TColor.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Promotion Badge
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
                  promotion.formattedDiscount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Promotion Name
              Text(
                promotion.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Promotion Description
              if (promotion.description.isNotEmpty) ...[
                Text(
                  promotion.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Validity Period
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Valid until: ${DateFormat('MMM dd, yyyy').format(promotion.endDate.toLocal())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Days Remaining
              if (daysRemaining > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: daysRemaining <= 3 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    daysRemaining == 1
                        ? '1 day left'
                        : '$daysRemaining days left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
