import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/location_controller.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/services/image_precache_service.dart';
import 'package:food_delivery_customer_app/views/screens/Home_view/categories.dart';
import 'package:food_delivery_customer_app/views/screens/Home_view/featured.dart';
import 'package:food_delivery_customer_app/views/screens/Home_view/popular_restaurants.dart';
import 'package:food_delivery_customer_app/views/screens/Home_view/promo.dart';
import 'package:food_delivery_customer_app/views/screens/favorite.dart';
import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/location_selection.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:get/get.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;
  final UserController _userController = Get.find<UserController>();
  final CartController _cartController = Get.find<CartController>();
  final OrderController _orderController =
      Get.find<OrderController>(); // Add this
  final LocationController locationController = Get.find<LocationController>();
  final RestaurantController restaurantController =
      Get.find<RestaurantController>();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });

    // Initialize user-dependent services when home page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserServices();
    });
  }

  void _initializeUserServices() async {
    final userController = Get.find<UserController>();
    final cartController = Get.find<CartController>();
    final wishlistController = Get.find<WishlistController>();

    if (userController.isLoggedIn && userController.user != null) {
      final accessToken = userController.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        try {
          // Only init services that haven't been loaded yet
          final futures = <Future>[];

          if (!cartController.hasItems && cartController.cart == null) {
            futures.add(
              cartController.initializeCart(accessToken: accessToken),
            );
          }
          futures.add(
            _orderController.initializeOrders(accessToken: accessToken),
          );
          if (wishlistController.wishlist == null) {
            futures.add(wishlistController.loadWishlist(accessToken));
          }
          if (restaurantController.featuredItemsWithPromotions.isEmpty) {
            futures.add(
              restaurantController.getFeaturedItemsWithPromotions(
                showLoading: false,
              ),
            );
          }

          if (futures.isNotEmpty) {
            await Future.wait(futures);
          }
        } catch (e) {
          print('⚠️ Error initializing user services: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _unfocusSearch() {
    _focusNode.unfocus();
    _controller.clear();
  }

  Widget _buildLocationHeader() {
    return Column(
      children: [
        // Top row: greeting + orders badge
        Obx(() {
          final user = _userController.user;
          return Padding(
            padding: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (user != null) ...[
                  Text(
                    'Hi, ${user.displayName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TColor.primaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _buildOrdersNotificationBadge(),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        // Location bar - compact pill style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () async {
              final selectedLocation = await Get.to(
                () => LocationSelectionScreen(),
              );
              if (selectedLocation != null) {
                locationController.updateSelectedLocation(selectedLocation);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Location pin with pulse ring
                  Obx(() {
                    final hasLocation =
                        locationController.selectedLocation != null;
                    final isGettingLocation =
                        locationController.isGettingLocationValue;
          
                    if (isGettingLocation) {
                      return SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TColor.primary,
                        ),
                      );
                    }
          
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: hasLocation
                            ? TColor.primary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: hasLocation ? TColor.primary : Colors.grey,
                        size: 18,
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
          
                  // Address text
                  Expanded(
                    child: Obx(() {
                      final location = locationController.selectedLocation;
                      final isGettingLocation =
                          locationController.isGettingLocationValue;
          
                      if (isGettingLocation) {
                        return Text(
                          "Getting your location...",
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        );
                      }
          
                      return Text(
                        location?.address ?? "Set delivery location",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: location != null
                              ? TColor.primaryText
                              : Colors.grey[400],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),
          
                  const SizedBox(width: 6),
                  Obx(() {
                    final isGettingLocation =
                        locationController.isGettingLocationValue;
                    return isGettingLocation
                        ? const SizedBox(width: 16, height: 16)
                        : Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: TColor.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: TColor.primary,
                              size: 20,
                            ),
                          );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersNotificationBadge() {
    return GestureDetector(
      onTap: () {
        print('📱 Orders icon tapped - navigating to OrdersPage');
        Get.to(() => OrdersPage());
      },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long,
              color: TColor.primaryText,
              size: 24,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Obx(() {
              final notificationCount = _orderController.notificationCount;

              print('🎯 Orders badge - Count: $notificationCount');

              if (notificationCount == 0) {
                return const SizedBox();
              }

              return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  notificationCount > 9 ? '9+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              // Clear restaurant data and reset loading state
              await restaurantController.onUserLogout();

              // Clear user data
              _userController.clearUser();

              // Navigate to get started screen
              Get.to(() => const GetStarted());

              // Show success message
              Get.snackbar(
                'Success',
                'Logged out successfully',
                snackPosition: SnackPosition.TOP,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Obx(() {
          // Show smooth shimmers ONLY on initial load (first launch or fresh login)
          if (restaurantController.isInitialLoading.value) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Fake Location Header Shimmer
                  AppShimmer(
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CategoryShimmer(),
                  const SizedBox(height: 20),
                  const PromoBannerShimmer(),
                  const SizedBox(height: 20),
                  const Text(
                    "Popular Restaurants",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) =>
                          const RestaurantCardShimmer(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Featured Menu Items",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  const MenuItemCardShimmer(),
                  const MenuItemCardShimmer(),
                ],
              ),
            );
          }

          // Normal content - background syncing happens without blocking UI
          return RefreshIndicator(
            onRefresh: () async {
              // Pull to refresh - background sync without loading indicator
              await Future.wait([
                restaurantController.refreshRestaurants(),
                restaurantController.refreshMenuItems(),
                restaurantController.getFeaturedItemsWithPromotions(
                  showLoading: false,
                ),
              ]);
              // Trigger background image pre-caching after refresh
              if (Get.isRegistered<ImagePreCacheService>()) {
                Get.find<ImagePreCacheService>().triggerPreCache();
              }
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location and Profile with enhanced styling
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 500),
                    child: _buildLocationHeader(),
                  ),

                  const SizedBox(height: 15),
                  // Categories Widget
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 100),
                    child: const CategoriesWidget(),
                  ),

                  const SizedBox(height: 15),

                  FadeSlideIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 200),
                    child: PromoBannerWidget(
                      featuredItemsWithPromotions:
                          restaurantController.featuredItemsWithPromotions,
                      onBannerTap: () {
                        print('🏷️ Promo banner tapped');
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Popular Restaurants Widget
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                    child: const PopularRestaurantsWidget(),
                  ),

                  const SizedBox(height: 15),

                  // Featured Menu Items
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 400),
                    child: const MenuItemsWidget(),
                  ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
