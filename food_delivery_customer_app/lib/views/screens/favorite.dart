import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/cart.dart';
import 'package:food_delivery_customer_app/utils/url_utils.dart';
import 'package:food_delivery_customer_app/views/screens/order_detail.dart';
import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with TickerProviderStateMixin {
  final OrderController _orderController = Get.find<OrderController>();
  final UserController _userController = Get.find<UserController>();
  final CartController _cartController = Get.find<CartController>();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Load orders when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
      _clearNotificationsOnOpen();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _clearNotificationsOnOpen() async {
    print('📱 OrdersPage opened - clearing notifications');
    await _orderController.clearNotifications();
  }

  Future<void> _loadOrders() async {
    if (_userController.isLoggedIn) {
      await _orderController.getUserOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Orders',
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
                Tab(text: 'Ongoing'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Obx(() {
        // Show login prompt if user is not logged in
        if (!_userController.isLoggedIn) {
          return _buildLoginPrompt();
        }

        if (_orderController.isLoading.value) {
          return _buildLoadingState();
        }

        if (_orderController.orders.isEmpty) {
          return _buildEmptyState();
        }

        // Split orders into ongoing and history
        final ongoingOrders = _orderController.orders.where((order) {
          final status = order.status.toLowerCase();
          return status == 'pending' ||
              status == 'placed' ||
              status == 'accepted' ||
              status == 'preparing' ||
              status == 'ready' ||
              status == 'out_for_delivery';
        }).toList();

        final historyOrders = _orderController.orders.where((order) {
          final status = order.status.toLowerCase();
          return status == 'delivered' ||
              status == 'completed' ||
              status == 'cancelled';
        }).toList();

        return TabBarView(
          controller: _tabController,
          children: [
            // Ongoing Orders Tab
            ongoingOrders.isEmpty
                ? _buildEmptyTabState(
                    'No ongoing orders',
                    'All your active orders will appear here',
                  )
                : _buildOrdersList(ongoingOrders),
            // History Tab
            historyOrders.isEmpty
                ? _buildEmptyTabState(
                    'No order history',
                    'Your completed orders will appear here',
                  )
                : _buildOrdersList(historyOrders),
          ],
        );
      }),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isCompleted =
        order.status.toLowerCase() == 'delivered' ||
        order.status.toLowerCase() == 'completed';

    // Get first item for display
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    return GestureDetector(
      onTap: () => Get.to(() => OrderDetailPage(order: order)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Image
                Builder(
                  builder: (context) {
                    // Normalize cached URL through UrlUtils
                    final rawUrl = firstItem?.menuItem.imageUrl;
                    final imageUrl = UrlUtils.ensureAbsoluteUrl(rawUrl);

                    return Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.fastfood,
                                    color: Colors.grey[400],
                                    size: 30,
                                  );
                                },
                              )
                            : Icon(
                                Icons.fastfood,
                                color: Colors.grey[400],
                                size: 30,
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Order Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: dish name + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              firstItem?.menuItem.title ?? 'Order Items',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: TColor.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                order.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatStatus(order.status),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Order code + date
                      Text(
                        '#${order.id}  •  ${_formatDate(order.placedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),

                      const SizedBox(height: 6),

                      // Rating display (for completed orders)
                      if (isCompleted && order.rating != null)
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Icon(
                                  i < (order.rating ?? 0)
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: i < (order.rating ?? 0)
                                      ? Colors.amber
                                      : Colors.grey[300],
                                  size: 18,
                                ),
                              );
                            }),
                            if (order.ratingComment != null &&
                                order.ratingComment!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      // Bottom row: price + action button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyFormatter.format(order.totalAmount),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: TColor.primary,
                            ),
                          ),
                          // Rate button for completed unrated orders
                          if (isCompleted && order.rating == null)
                            SizedBox(
                              height: 32,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: TColor.primary,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onPressed: () => _showRatingDialog(order),
                                icon: Icon(
                                  Icons.star_outline_rounded,
                                  color: TColor.primary,
                                  size: 16,
                                ),
                                label: Text(
                                  'Rate',
                                  style: TextStyle(
                                    color: TColor.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          // View details arrow for ongoing orders
                          if (!isCompleted)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(Order order) {
    int rating = 0;
    String comment = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Rate your order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Add a comment (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    comment = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                ),
                onPressed: rating > 0
                    ? () async {
                        Get.back();
                        await _orderController.rateOrder(
                          order.id,
                          rating: rating.toDouble(),
                          review: comment.isNotEmpty ? comment : null,
                        );
                        Get.snackbar(
                          'Success',
                          'Thank you for your rating!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      }
                    : null,
                child: const Text(
                  'Submit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reorderItems(Order order) async {
    try {
      // Add all order items to cart
      for (final item in order.items) {
        await _cartController.addToCart(
          menuItem: item.menuItem,
          quantity: item.quantity,
          accessToken: _userController.accessToken,
        );
      }

      Get.snackbar(
        'Success',
        '${order.items.length} item(s) added to cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navigate to cart
      Get.back(); // Close orders page
      // The user can then navigate to cart from main tab
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to re-order: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildEmptyTabState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
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

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Login Required',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please login to view your orders',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              Get.toNamed('/login');
            },
            child: const Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            'Loading your orders...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your order history will appear here',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              Get.back(); // Go back to main screen
            },
            child: const Text(
              'Start Shopping',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd').format(date.toLocal());
  }

  String _formatStatus(String status) {
    // Convert status to readable format
    switch (status.toLowerCase()) {
      case 'out_for_delivery':
        return 'Out for Delivery';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'pending':
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
}
