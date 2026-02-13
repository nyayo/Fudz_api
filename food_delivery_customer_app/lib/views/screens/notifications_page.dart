import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/views/screens/order_detail.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final OrderController _orderController = Get.find<OrderController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Clear notifications when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orderController.clearNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: TColor.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: TColor.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: TColor.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Orders'),
                Tab(text: 'Promotions'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [OrderNotificationsTab(), PromotionNotificationsTab()],
      ),
    );
  }
}

// Order Notifications Tab
class OrderNotificationsTab extends StatelessWidget {
  const OrderNotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.find<OrderController>();

    return Obx(() {
      final orders = orderController.orders;

      if (orders.isEmpty) {
        return _buildEmptyState(
          icon: Icons.notifications_none,
          title: 'No order notifications',
          subtitle: 'Updates about your orders will appear here',
        );
      }

      // Get recent orders (last 10)
      final recentOrders = orders.take(10).toList();

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recentOrders.length,
        itemBuilder: (context, index) {
          final order = recentOrders[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildOrderNotificationCard(context, order),
          );
        },
      );
    });
  }

  Widget _buildOrderNotificationCard(BuildContext context, order) {
    final statusMessage = _getStatusMessage(order.status);
    final statusColor = _getStatusColor(order.status);

    return GestureDetector(
      onTap: () {
        Get.to(() => OrderDetailPage(order: order));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(order.status),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TColor.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(order.placedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Arrow icon
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return 'Your order has been placed successfully';
      case 'accepted':
        return 'Restaurant has accepted your order';
      case 'preparing':
        return 'Your order is being prepared';
      case 'ready':
        return 'Your order is ready for pickup';
      case 'out_for_delivery':
        return 'Your order is on the way';
      case 'delivered':
      case 'completed':
        return 'Your order has been delivered';
      case 'cancelled':
        return 'Your order has been cancelled';
      default:
        return 'Order status updated';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return Icons.receipt;
      case 'accepted':
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.check_circle;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'placed':
        return Colors.orange;
      case 'accepted':
      case 'preparing':
        return Colors.blue;
      case 'ready':
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Promotion Notifications Tab
class PromotionNotificationsTab extends StatelessWidget {
  const PromotionNotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock promotion data for demonstration
    final List<Map<String, dynamic>> promotions = [
      {
        'title': '50% Off On Your First Order',
        'description':
            'Use code FIRST50 to get 50% discount on your first order',
        'validUntil': DateTime.now().add(const Duration(days: 7)),
        'icon': Icons.local_offer,
        'color': Colors.green,
      },
      {
        'title': 'Free Delivery Weekend',
        'description': 'Enjoy free delivery on all orders this weekend',
        'validUntil': DateTime.now().add(const Duration(days: 3)),
        'icon': Icons.delivery_dining,
        'color': Colors.blue,
      },
      {
        'title': 'Happy Hour Special',
        'description': 'Get 30% off on selected restaurants from 3-6 PM',
        'validUntil': DateTime.now().add(const Duration(days: 1)),
        'icon': Icons.access_time,
        'color': Colors.orange,
      },
    ];

    if (promotions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.card_giftcard,
        title: 'No promotions available',
        subtitle: 'Check back later for exciting offers',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: promotions.length,
      itemBuilder: (context, index) {
        final promo = promotions[index];
        return _buildPromotionCard(promo);
      },
    );
  }

  Widget _buildPromotionCard(Map<String, dynamic> promo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Promotion icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: promo['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(promo['icon'], color: promo['color'], size: 28),
          ),
          const SizedBox(width: 12),

          // Promotion content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TColor.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  promo['description'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Valid until ${DateFormat('MMM dd').format(promo['validUntil'])}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
