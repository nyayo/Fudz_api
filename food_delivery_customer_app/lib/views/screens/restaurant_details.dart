import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/restaurant.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';

class RestaurantDetailPage extends StatefulWidget {
  final int restaurantId;

  const RestaurantDetailPage({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  final RestaurantController restaurantController = Get.find();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _selectedCategoryIndex = ValueNotifier<int>(0);
  final ValueNotifier<String> _selectedCategoryName = ValueNotifier<String>('');

  // Track filtered menu items by category
  final RxList<MenuItem> _filteredMenuItems = <MenuItem>[].obs;
  final RxList<dynamic> _restaurantCategories = <dynamic>[].obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restaurantController.getRestaurantDetail(widget.restaurantId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectedCategoryIndex.dispose();
    _selectedCategoryName.dispose();
    super.dispose();
  }

  // Extract categories specific to this restaurant
  void _extractRestaurantCategories() {
    final restaurant = restaurantController.selectedRestaurant.value;
    if (restaurant != null && restaurant.categories != null) {
      _restaurantCategories.value = restaurant.categories!;
      print(
        '🏪 Found ${_restaurantCategories.length} categories for restaurant ${restaurant.restaurantName}',
      );

      // Auto-select first category if available
      if (_restaurantCategories.isNotEmpty) {
        _filterMenuItemsByCategory(0);
      }
    } else {
      _restaurantCategories.value = [];
      print('🏪 No categories found for restaurant');
    }
  }

  // Get restaurant-specific menu items
  List<MenuItem> get _restaurantMenuItems {
    return restaurantController.menuItems.where((item) {
      // Filter items that belong to this specific restaurant
      return item.restaurantId == widget.restaurantId;
    }).toList();
  }

  // Method to filter menu items by category
  void _filterMenuItemsByCategory(int categoryIndex) {
    _selectedCategoryIndex.value = categoryIndex;

    if (categoryIndex < _restaurantCategories.length) {
      final category = _restaurantCategories[categoryIndex];
      final categoryId = _getCategoryId(category);
      final categoryName = _getCategoryName(category);

      _selectedCategoryName.value = categoryName;

      // Filter menu items by category ID AND restaurant ID
      final filteredItems = _restaurantMenuItems.where((item) {
        final itemCategoryId = item.category;

        // Handle different category ID types (int, String, etc.)
        return itemCategoryId == categoryId;
              return false;
      }).toList();

      _filteredMenuItems.value = filteredItems;

      print(
        '🔍 Filtered $categoryName: ${filteredItems.length} items (Category ID: $categoryId)',
      );
      print(
        '🏪 Restaurant ID: ${widget.restaurantId}, Total restaurant items: ${_restaurantMenuItems.length}',
      );
    }
  }

  // Helper method to get category ID from different data structures
  dynamic _getCategoryId(dynamic category) {
    if (category is Map<String, dynamic>) {
      return category['id'];
    } else if (category is int) {
      return category;
    } else if (category is String) {
      return int.tryParse(category);
    }
    return null;
  }

  // Helper method to get category name from different data structures
  String _getCategoryName(dynamic category) {
    if (category is Map<String, dynamic>) {
      return category['name'] ?? 'Category';
    } else if (category is int) {
      return 'Category $category';
    } else if (category is String) {
      return category;
    }
    return 'Category';
  }

  // Get item count for a specific category (restaurant-specific)
  int _getCategoryItemCount(int categoryIndex) {
    if (categoryIndex < _restaurantCategories.length) {
      final category = _restaurantCategories[categoryIndex];
      final categoryId = _getCategoryId(category);

      return _restaurantMenuItems.where((item) {
        final itemCategoryId = item.category;

        // Handle different category ID types
        return itemCategoryId == categoryId;
              return false;
      }).length;
    }
    return 0;
  }

  // Get total categories count for the restaurant
  int _getTotalCategoriesCount() {
    return _restaurantCategories.length;
  }

  // Get total menu items count for this specific restaurant
  int _getTotalMenuItemsCount() {
    return _restaurantMenuItems.length;
  }

  // Initialize filtered items when menu items load
  void _initializeFilteredItems() {
    if (restaurantController.menuItems.isNotEmpty) {
      _extractRestaurantCategories();
      print(
        '✅ Initialized with ${_restaurantMenuItems.length} restaurant-specific items and ${_restaurantCategories.length} categories',
      );
      print(
        '📊 All menu items in controller: ${restaurantController.menuItems.length}',
      );
      print('🎯 Restaurant ID: ${widget.restaurantId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        if (restaurantController.isLoadingDetails.value) {
          return _buildLoadingState();
        }

        final restaurant = restaurantController.selectedRestaurant.value;
        if (restaurant == null) {
          return _buildErrorState('Restaurant not found');
        }

        // Initialize filtered items when menu items are loaded
        if (_filteredMenuItems.isEmpty &&
            restaurantController.menuItems.isNotEmpty) {
          _initializeFilteredItems();
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(restaurant),
            _buildRestaurantInfo(restaurant),
            _buildCategoryList(),
            _buildMenuItemsHeader(),
            _buildMenuItems(),
          ],
        );
      }),
    );
  }

  SliverToBoxAdapter _buildCategoryList() {
    return SliverToBoxAdapter(
      child: Obx(() {
        if (_restaurantCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Builder(
                  builder: (context) => Text(
                    'Menu Categories',
                    style: ResponsiveText.heading3(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _restaurantCategories.length,
                  itemBuilder: (context, index) {
                    final category = _restaurantCategories[index];
                    final categoryName = _getCategoryName(category);
                    final itemCount = _getCategoryItemCount(index);

                    return ValueListenableBuilder<int>(
                      valueListenable: _selectedCategoryIndex,
                      builder: (context, selectedIndex, child) {
                        final isSelected = selectedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8,),
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(categoryName),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : TColor.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Builder(
                                    builder: (context) => Text(
                                      itemCount.toString(),
                                      style: ResponsiveText.tiny(
                                        context,
                                        color: isSelected ? Colors.white : TColor.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: TColor.primary,
                            backgroundColor: Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            onSelected: (selected) {
                              _filterMenuItemsByCategory(index);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }

  SliverToBoxAdapter _buildMenuItemsHeader() {
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<String>(
        valueListenable: _selectedCategoryName,
        builder: (context, categoryName, child) {
          if (categoryName.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Builder(
                  builder: (context) => Text(
                    categoryName,
                    style: ResponsiveText.heading3(
                      context,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() {
                  final itemCount = _filteredMenuItems.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TColor.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Builder(
                      builder: (context) => Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: ResponsiveText.caption(
                          context,
                          color: TColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItems() {
    return Obx(() {
      if (restaurantController.isLoadingMenuItems.value) {
        return SliverToBoxAdapter(
          child: Column(
            children: List.generate(3, (index) => _buildMenuItemShimmer()),
          ),
        );
      }

      if (_filteredMenuItems.isEmpty) {
        return SliverToBoxAdapter(child: _buildNoMenuItems());
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final menuItem = _filteredMenuItems[index];
          return _buildMenuItemCard(menuItem);
        }, childCount: _filteredMenuItems.length),
      );
    });
  }

  Widget _buildMenuItemCard(MenuItem menuItem) {
    final cartController = Get.find<CartController>();
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return GestureDetector(
      onTap: () {
        Get.to(MenuItemDetailPage(menuItemId: menuItem.id));
      },
      child: Container(
        margin: const EdgeInsets.only(left:20, right:20, bottom:20 ),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CachedImage(
                imageUrl: menuItem.imageUrl,
                width: 80,
                height: 80,
                borderRadius: 12,
                placeholderIcon: Icons.fastfood,
              ),
            ),

            const SizedBox(width: 16),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) => Text(
                      menuItem.title,
                      style: ResponsiveText.heading4(context),
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (menuItem.description != null &&
                      menuItem.description!.isNotEmpty)
                    Builder(
                      builder: (context) => Text(
                        menuItem.description!,
                        style: ResponsiveText.caption(context, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Dietary Info
                  if ((menuItem.dietaryInfo ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Builder(
                        builder: (context) => Text(
                          menuItem.dietaryInfo!,
                          style: ResponsiveText.tiny(
                            context,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Availability
                  Builder(
                    builder: (context) => Text(
                      menuItem.isAvailable ? 'Available' : 'Not Available',
                      style: ResponsiveText.tiny(
                        context,
                        color: menuItem.isAvailable ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => Text(
                          menuItem.formattedPrice,
                          style: ResponsiveText.price(context),
                        ),
                      ),
                      if (menuItem.isAvailable)
                        Container(
                          decoration: BoxDecoration(
                            color: TColor.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Obx(() {
                            final isProcessing = cartController
                                .isItemProcessing('${menuItem.id}_add');
                            final isInCart = cartController.isItemInCart(menuItem.id);
                            
                            return IconButton(
                              icon: isProcessing
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              TColor.primary,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      isInCart ? Icons.check_circle : Icons.add_circle,
                                      color: isInCart ? Colors.grey : TColor.primary,
                                      size: (cardWidth * 0.10).clamp(
                                        18.0,
                                        24.0,
                                      ),
                                    ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: cardWidth * 0.16,
                                minHeight: cardWidth * 0.16,
                              ),
                              onPressed: (isProcessing || isInCart)
                                  ? null
                                  : () async {
                                      final userController =
                                          Get.find<UserController>();
                                      if (!userController.isLoggedIn) {
                                        Get.snackbar(
                                          'Login Required',
                                          'Please login to add items to cart',
                                          snackPosition: SnackPosition.TOP,
                                          backgroundColor: Colors.orange,
                                          colorText: Colors.white,
                                        );
                                        return;
                                      }

                                      try {
                                        await cartController.addToCart(
                                          menuItem: menuItem,
                                          quantity: 1,
                                          accessToken:
                                              userController.accessToken,
                                        );
                                      } catch (e) {
                                        // Error handled by controller
                                      }
                                    },
                            );
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMenuItems() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: _selectedCategoryName,
            builder: (context, categoryName, child) {
              return Text(
                'No $categoryName Items Available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: _selectedCategoryName,
            builder: (context, categoryName, child) {
              return Text(
                'This restaurant hasn\'t added any items in the $categoryName category yet.',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Select first category if available
              if (_restaurantCategories.isNotEmpty) {
                _filterMenuItemsByCategory(0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'View Other Categories',
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

  SliverAppBar _buildAppBar(RestaurantProfile restaurant) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: TColor.primary),
          onPressed: () => Get.back(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.favorite_border, color: TColor.primary),
            onPressed: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            restaurant.imageUrl != null
                ? CachedImage(
                    imageUrl: restaurant.imageUrl,
                    width: double.infinity,
                    height: 250,
                    borderRadius: 0,
                    placeholderIcon: Icons.restaurant,
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.restaurant,
                      color: Colors.grey[500],
                      size: 80,
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (restaurant.logoUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: CachedImage(
                            imageUrl: restaurant.logoUrl,
                            width: 50,
                            height: 50,
                            borderRadius: 25,
                            placeholderIcon: Icons.restaurant,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          restaurant.restaurantName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Various Cuisine',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildRestaurantInfo(RestaurantProfile restaurant) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: restaurant.isOpen
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: restaurant.isOpen
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        restaurant.isOpen
                            ? Icons.circle
                            : Icons.circle_outlined,
                        color: restaurant.isOpen ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        restaurant.isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: restaurant.isOpen ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    value: _getTotalMenuItemsCount().toString(),
                    label: 'Items',
                  ),
                  _buildStatItem(
                    value: _getTotalCategoriesCount().toString(),
                    label: 'Categories',
                  ),
                  _buildStatItem(
                    value: restaurant.rating.toStringAsFixed(1),
                    label: 'Rating',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.location_on,
                    title: 'Address',
                    value: restaurant.address,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.person,
                    title: 'Owner',
                    value: restaurant.ownerName ?? 'Not specified',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: TColor.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: TColor.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Container(width: 60, height: 16, color: Colors.grey[300]),
              ],
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
            'Loading restaurant details...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Restaurant ID: ${widget.restaurantId}',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  restaurantController.getRestaurantDetail(widget.restaurantId);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
