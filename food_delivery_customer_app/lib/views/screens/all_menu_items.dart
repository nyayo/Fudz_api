import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/views/screens/item_detail.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';
import 'package:food_delivery_customer_app/views/widgets/shimmer_widgets.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';

class AllMenuItemsPage extends StatefulWidget {
  const AllMenuItemsPage({super.key});

  @override
  State<AllMenuItemsPage> createState() => _AllMenuItemsPageState();
}

class _AllMenuItemsPageState extends State<AllMenuItemsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final restaurantController = Get.find<RestaurantController>();
  final cartController = Get.find<CartController>();
  final userController = Get.find<UserController>();
  final ScrollController _scrollController = ScrollController();

  final RxList<MenuItem> _filteredItems = <MenuItem>[].obs;
  final RxBool _isSearching = false.obs;
  final RxString _searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    // Initialize with all items
    _filteredItems.value = restaurantController.menuItems;

    // Listen for search text changes
    _searchController.addListener(_onSearchChanged);

    // Initial load if needed
    if (restaurantController.allMenuItems.isEmpty) {
      restaurantController.getMenuItems(showLoading: true);
    }

    // Scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isSearching.value) {
        restaurantController.getMenuItems(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchQuery.value = query;
    _isSearching.value = query.isNotEmpty;

    if (query.isEmpty) {
      _filteredItems.value = restaurantController.menuItems;
      return;
    }

    final searchLower = query.toLowerCase();
    _filteredItems.value = restaurantController.menuItems.where((item) {
      // Search in title
      if (item.title.toLowerCase().contains(searchLower)) return true;

      // Search in description
      if (item.description != null &&
          item.description!.toLowerCase().contains(searchLower))
        return true;

      // Search in restaurant name
      if (item.restaurantName != null &&
          item.restaurantName!.toLowerCase().contains(searchLower))
        return true;

      // Search in dietary info
      if (item.dietaryInfo != null &&
          item.dietaryInfo!.toLowerCase().contains(searchLower))
        return true;

      return false;
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _isSearching.value = false;
    _searchQuery.value = '';
    _filteredItems.value = restaurantController.menuItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar with Search
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            floating: true,
            snap: true,
            expandedHeight: 56, // Minimal height
            automaticallyImplyLeading: false, // No back arrow
            title: Row(
              children: [
                // Back Arrow
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 8),

                // Search Field Expanded
                Expanded(child: _buildSearchField()),
              ],
            ),
            centerTitle: false,
            titleSpacing: 16, // Add some spacing
          ),

          // Search results count
          Obx(() {
            if (_searchQuery.value.isNotEmpty) {
              return SliverToBoxAdapter(
                child: _buildSearchResultsInfo(context),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),

          // Results or loading/empty state
          Obx(() {
            if (restaurantController.isLoadingMenuItemsValue) {
              return SliverToBoxAdapter(child: _buildLoadingState());
            }

            final items = _filteredItems;

            if (items.isEmpty && _searchQuery.value.isNotEmpty) {
              return SliverToBoxAdapter(child: _buildNoResultsState());
            }

            if (items.isEmpty) {
              return SliverToBoxAdapter(child: _buildEmptyState());
            }

            return SliverMainAxisGroup(
              slivers: [
                _buildMenuItemsList(items),
                if (!_isSearching.value)
                  SliverToBoxAdapter(
                    child: Obx(
                      () => restaurantController.isLoadingMoreMenuItems.value
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: TColor.primary,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : const SizedBox(height: 50),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50, // Small height
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18), // More rounded
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 16, // Smaller icon
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                border: InputBorder.none,
                hintStyle: ResponsiveText.bodySmall(
                  context,
                  color: Colors.grey,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              style: ResponsiveText.bodySmall(context, color: Colors.black87),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _searchFocusNode.unfocus();
              },
            ),
          ),
          Obx(() {
            if (_searchQuery.value.isNotEmpty) {
              return IconButton(
                icon: Icon(
                  Icons.clear,
                  color: Colors.grey[500],
                  size: 16, // Smaller icon
                ),
                onPressed: _clearSearch,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              );
            }
            return const SizedBox(width: 8);
          }),
        ],
      ),
    );
  }

  Widget _buildSearchResultsInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Search Results',
              style: ResponsiveText.body(
                context,
                fontWeight: FontWeight.w600,
                color: TColor.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Obx(() {
            final count = _filteredItems.length;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: TColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count ${count == 1 ? 'item' : 'items'}',
                style: ResponsiveText.tiny(
                  context,
                  color: TColor.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItemsList(RxList<MenuItem> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index % 8) * 80),
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
          child: _buildMenuItemCard(item, index == items.length - 1),
        );
      }, childCount: items.length),
    );
  }

  // Update the _buildMenuItemCard method in AllMenuItemsPage

  Widget _buildMenuItemCard(MenuItem item, bool isLastItem) {
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText = hasPromotion
        ? item.formattedDiscountedPrice
        : item.formattedPrice;
    final String? originalPriceText = hasPromotion ? item.formattedPrice : null;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, isLastItem ? 20 : 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Get.to(() => MenuItemDetailPage(menuItemId: item.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image with Promotion Badge
                Stack(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CachedImage(
                        imageUrl: item.safeImageUrl,
                        width: 100,
                        height: 100,
                        borderRadius: 12,
                        placeholderIcon: Icons.fastfood,
                      ),
                    ),
                    if (hasPromotion)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            '${item.activePromotions.first.formattedDiscount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Item Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) => Text(
                                item.title,
                                style: ResponsiveText.heading3(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Builder(
                                builder: (context) => Text(
                                  priceText,
                                  style: ResponsiveText.priceSize(
                                    context,
                                    color: hasPromotion
                                        ? Colors.red
                                        : TColor.primary,
                                  ),
                                ),
                              ),
                              if (originalPriceText != null)
                                Text(
                                  originalPriceText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Promotion Name
                      if (hasPromotion)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.activePromotions.first.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Description
                      if (item.description != null &&
                          item.description!.isNotEmpty)
                        Text(
                          item.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),
                      // Add to Cart Button
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.isAvailable
                                ? TColor.primary
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: item.isAvailable
                              ? () async {
                                  if (cartController.isItemProcessing(
                                    '${item.id}_add',
                                  ))
                                    return;
                                  if (cartController.isItemInCart(item.id))
                                    return;

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
                                      menuItem: item,
                                      quantity: 1,
                                      accessToken: userController.accessToken,
                                    );
                                  } catch (e) {
                                    // Error is handled by CartController via SnackbarService
                                  }
                                }
                              : null,
                          child: Obx(() {
                            final isProcessing = cartController
                                .isItemProcessing('${item.id}_add');
                            final isInCart = cartController.isItemInCart(
                              item.id,
                            );

                            if (isProcessing) {
                              return const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isInCart
                                      ? Icons.check_circle
                                      : Icons.shopping_cart,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isInCart ? 'Added' : 'Add to Cart',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isInCart
                                        ? Colors.white70
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
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

  Widget _buildNoResultsState() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"${_searchController.text}"',
              style: TextStyle(
                color: TColor.primary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: TColor.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Clear Search',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) => MenuItemCardShimmer(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No Menu Items Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for delicious menu items',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                restaurantController.refreshMenuItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TColor.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
