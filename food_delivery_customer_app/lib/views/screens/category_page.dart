import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/category_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:get/get.dart';

class CategoryPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final CategoryController categoryController = Get.find();
  final ApiService _apiService = Get.find();
  final UserController _userController = Get.find<UserController>();
  final CartController _cartController = Get.find<CartController>();

  String _searchQuery = '';
  bool _isSearching = false;
  final RxList<MenuItem> _categoryMenuItems = <MenuItem>[].obs;
  final RxBool _isLoadingMenuItems = false.obs;

  @override
  void initState() {
    super.initState();
    print('🔵 CategoryPage initState - categoryId: ${widget.categoryId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoryMenuItems();
    });
  }

  Future<void> _loadCategoryMenuItems() async {
    try {
      _isLoadingMenuItems.value = true;
      print('🔍 Loading menu items for category: ${widget.categoryId}');

      // Try the category-specific endpoint first
      try {
        final response = await _apiService.get(
          'restaurants/categories/${widget.categoryId}/items/',
        );

        List<dynamic> itemsList = [];

        if (response is List) {
          itemsList = response;
        } else if (response is Map && response.containsKey('data')) {
          itemsList = response['data'] ?? [];
        } else if (response is Map && response.containsKey('results')) {
          itemsList = response['results'] ?? [];
        }

        if (itemsList.isNotEmpty) {
          final menuItems = itemsList
              .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
              .where((item) => item.isAvailable)
              .toList();

          _categoryMenuItems.value = menuItems;
          print(
            '✅ Loaded ${menuItems.length} menu items from category endpoint',
          );
          return;
        }
      } catch (e) {
        print('⚠️ Category-specific endpoint not available: $e');
      }

      // Fallback: Fetch all menu items and filter by category
      print('🔄 Fetching all menu items and filtering by category...');
      final response = await _apiService.get('restaurants/items/');

      List<dynamic> itemsList = [];

      if (response is List) {
        itemsList = response;
      } else if (response is Map && response.containsKey('data')) {
        itemsList = response['data'] ?? [];
      } else if (response is Map && response.containsKey('results')) {
        itemsList = response['results'] ?? [];
      }

      print('📦 Total items fetched: ${itemsList.length}');

      final menuItems = itemsList
          .map((item) {
            try {
              return MenuItem.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              print('❌ Error parsing menu item: $e');
              return null;
            }
          })
          .whereType<MenuItem>()
          .where((item) {
            // Filter by category
            final itemCategory = item.category;
            final matchesCategory = itemCategory == widget.categoryId;

            // Only show available items
            final isAvailable = item.isAvailable;

            if (matchesCategory) {
              print('✅ Found item: ${item.title} (category: $itemCategory)');
            }

            return matchesCategory && isAvailable;
          })
          .toList();

      _categoryMenuItems.value = menuItems;
      print(
        '✅ Loaded ${menuItems.length} menu items for category ${widget.categoryId} after filtering',
      );

      if (menuItems.isEmpty) {
        print('⚠️ No menu items found for category ${widget.categoryId}');
        print('   This could mean:');
        print('   1. No items are assigned to this category');
        print('   2. All items in this category are unavailable');
        print('   3. The category field name might be different');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading category menu items: $e');
      print('❌ Stack trace: $stackTrace');
      Get.snackbar(
        'Error',
        'Failed to load menu items: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoadingMenuItems.value = false;
    }
  }

  List<MenuItem> get filteredMenuItems {
    if (_searchQuery.isEmpty) {
      return _categoryMenuItems;
    }

    return _categoryMenuItems.where((item) {
      final title = item.title.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // App Bar with Category Title
          SliverAppBar(
            backgroundColor: TColor.primary,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.categoryName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildSearchField(),
              ),
            ),
          ),

          // Menu Items Grid
          Obx(() {
            if (_isLoadingMenuItems.value) {
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const AppShimmer(
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                      ),
                    ),
                    childCount: 6,
                  ),
                ),
              );
            }

            if (filteredMenuItems.isEmpty) {
              return _buildEmptyState();
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final menuItem = filteredMenuItems[index];
                  return _buildMenuItemCard(menuItem);
                }, childCount: filteredMenuItems.length),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search ${widget.categoryName}...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.search, color: Colors.grey[500], size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 50,
            minHeight: 50,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _isSearching = value.isNotEmpty;
          });
        },
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem menuItem) {
    return GestureDetector(
      onTap: () {
        Get.to(() => MenuItemDetailPage(menuItemId: menuItem.id));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu Item Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[100],
                      child: menuItem.imageUrl != null
                          ? CachedImage(
                              imageUrl: menuItem.imageUrl,
                              fit: BoxFit.cover,
                              placeholderIcon: Icons.fastfood,
                            )
                          : Icon(
                              Icons.fastfood,
                              color: Colors.grey[400],
                              size: 50,
                            ),
                    ),
                  ),

                  // Promotion Badge
                  if (menuItem.hasActivePromotions)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          menuItem.activePromotions.first.formattedDiscount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Menu Item Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      menuItem.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: TColor.primaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Price and Add Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (menuItem.hasActivePromotions) ...[
                              Text(
                                menuItem.formattedDiscountedPrice,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: TColor.primary,
                                ),
                              ),
                              Text(
                                menuItem.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else
                              Text(
                                menuItem.formattedPrice,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: TColor.primary,
                                ),
                              ),
                          ],
                        ),

                        QuantityCounter(
                          cartController: _cartController,
                          menuItem: menuItem,
                          accessToken: _userController.isLoggedIn
                              ? _userController.accessToken
                              : null,
                          height: 36,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsLoading() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 12,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 80,
                              height: 12,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 60,
                              height: 14,
                              color: Colors.grey[300],
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }, childCount: 6),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              _isSearching
                  ? 'No items found for "$_searchQuery"'
                  : 'No ${widget.categoryName} items available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_isSearching)
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _isSearching = false;
                  });
                },
                child: Text(
                  'Clear search',
                  style: TextStyle(color: TColor.primary, fontSize: 16),
                ),
              )
            else
              TextButton.icon(
                onPressed: _loadCategoryMenuItems,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: TColor.primary),
              ),
          ],
        ),
      ),
    );
  }
}
