// views/screens/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/models/cart.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';

import 'package:intl/intl.dart';

class OrderDetailPage extends StatelessWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar with status header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _getStatusColor(order.status),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getStatusColor(order.status),
                      _getStatusColor(order.status).withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getStatusIcon(order.status),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatStatus(order.status),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusDescription(order.status),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status stepper
                  _buildStatusStepper(),
                  const SizedBox(height: 16),

                  // Restaurant info
                  if (order.restaurantName != null &&
                      order.restaurantName!.isNotEmpty)
                    _buildRestaurantCard(),

                  if (order.restaurantName != null &&
                      order.restaurantName!.isNotEmpty)
                    const SizedBox(height: 16),

                  // Order items
                  _buildOrderItemsCard(),
                  const SizedBox(height: 16),

                  // Payment summary
                  _buildPaymentSummary(),
                  const SizedBox(height: 16),

                  // Order info
                  _buildOrderInfoCard(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    final steps = [
      _StepData('Placed', Icons.receipt_long, 'placed'),
      _StepData('Accepted', Icons.check_circle_outline, 'accepted'),
      _StepData('Preparing', Icons.restaurant, 'preparing'),
      _StepData('Ready', Icons.takeout_dining, 'ready'),
      _StepData('Delivered', Icons.done_all, 'delivered'),
    ];

    final currentIndex = _getStatusIndex(order.status);
    final isCancelled = order.status.toLowerCase() == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: isCancelled
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: List.generate(steps.length * 2 - 1, (index) {
                    if (index.isOdd) {
                      // Connector line
                      final stepBefore = index ~/ 2;
                      return Expanded(
                        child: Container(
                          height: 3,
                          color: stepBefore < currentIndex
                              ? TColor.primary
                              : Colors.grey[300],
                        ),
                      );
                    }
                    final stepIndex = index ~/ 2;
                    final isActive = stepIndex <= currentIndex;
                    final isCurrent = stepIndex == currentIndex;
                    return Container(
                      width: isCurrent ? 36 : 28,
                      height: isCurrent ? 36 : 28,
                      decoration: BoxDecoration(
                        color: isActive ? TColor.primary : Colors.grey[200],
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: TColor.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        steps[stepIndex].icon,
                        color: isActive ? Colors.white : Colors.grey[400],
                        size: isCurrent ? 18 : 14,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: steps
                      .map(
                        (s) => SizedBox(
                          width: 56,
                          child: Text(
                            s.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildRestaurantCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.storefront, color: TColor.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restaurant',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  order.restaurantName!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

  Widget _buildOrderItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: TColor.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Items (${order.items.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...order.items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
            ),
            child:
                item.menuItem.imageUrl != null &&
                    item.menuItem.imageUrl!.trim().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.menuItem.imageUrl!.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.fastfood,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
                  )
                : Icon(Icons.fastfood, color: Colors.grey[400], size: 24),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TColor.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(item.unitPrice * item.quantity),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: TColor.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final subtotal = order.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_outlined, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Individual items breakdown
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.menuItem.title} x${item.quantity}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(item.unitPrice * item.quantity),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          Divider(color: Colors.grey[200], height: 24),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
              Text(
                CurrencyFormatter.format(subtotal),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: TColor.primary,
                ),
              ),
            ],
          ),

          // Payment status badge
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPaymentColor(order.paymentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  order.paymentStatus.toLowerCase() == 'paid'
                      ? Icons.check_circle
                      : Icons.pending,
                  color: _getPaymentColor(order.paymentStatus),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatStatus(order.paymentStatus),
                  style: TextStyle(
                    color: _getPaymentColor(order.paymentStatus),
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

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoTile(Icons.tag, 'Order ID', '#${order.id}'),
          _buildInfoTile(
            Icons.calendar_today,
            'Placed',
            _formatFullDate(order.placedAt),
          ),
          if (order.dropoffLocation != null)
            _buildInfoTile(
              Icons.location_on,
              'Delivery Address',
              order.dropoffLocation!['address'] ??
                  order.dropoffLocation!.toString(),
            ),
          if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
            _buildInfoTile(
              Icons.payment,
              'Payment Method',
              order.paymentMethod!,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.deepPurple;
      case 'ready':
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return Icons.receipt_long;
      case 'accepted':
        return Icons.thumb_up;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.takeout_dining;
      case 'out_for_delivery':
        return Icons.delivery_dining;
      case 'delivered':
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return 'Your order has been placed and is waiting for confirmation';
      case 'accepted':
        return 'The restaurant has accepted your order';
      case 'preparing':
        return 'Your food is being prepared with care';
      case 'ready':
        return 'Your order is ready and waiting for pickup';
      case 'out_for_delivery':
        return 'Your order is on the way to you';
      case 'delivered':
      case 'completed':
        return 'Your order has been delivered. Enjoy your meal!';
      case 'cancelled':
        return 'This order has been cancelled';
      default:
        return 'Order status updated';
    }
  }

  int _getStatusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return 0;
      case 'accepted':
        return 1;
      case 'preparing':
        return 2;
      case 'ready':
      case 'out_for_delivery':
        return 3;
      case 'delivered':
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'out_for_delivery':
        return 'Out for Delivery';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatFullDate(DateTime date) {
    try {
      return DateFormat("MMM dd, yyyy 'at' HH:mm").format(date.toLocal());
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _StepData {
  final String label;
  final IconData icon;
  final String status;
  _StepData(this.label, this.icon, this.status);
}
