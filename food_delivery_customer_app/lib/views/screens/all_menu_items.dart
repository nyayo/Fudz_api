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
import 'package:food_delivery_customer_app/views/widgets/quantity_counter_widget.dart';
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
  late final Worker _menuItemsWorker;

  final RxList<MenuItem> _filteredItems = <MenuItem>[].obs;
  final RxBool _isSearching = false.obs;
  final RxString _searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();

    // Listen for search text changes
    _searchController.addListener(_onSearchChanged);

    // Initial load if needed
    if (restaurantController.allMenuItems.isEmpty) {
      restaurantController.getMenuItems(showLoading: true);
    }

    // Keep filtered list in sync when menu items change
    _menuItemsWorker = ever(restaurantController.menuItems, (_) {
      if (!_isSearching.value) {
        _updateFilteredItems();
      }
    });

    // Seed initial filtered items
    _updateFilteredItems();

    // Scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isSearching.value) {
        restaurantController.getMenuItems(loadMore: true);
      }
    });
  }

  void _updateFilteredItems() {
    // Deduplicate by ID before setting
    final items = restaurantController.menuItems.toList();
    final seenIds = <int>{};
    final uniqueItems = items.where((item) => seenIds.add(item.id)).toList();
    _filteredItems.value = uniqueItems;
  }

  @override
  void dispose() {
    _menuItemsWorker.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchQuery.value = query;
    _isSearching.value = query.isNotEmpty;

    if (query.isEmpty) {
      _updateFilteredItems();
      return;
    }

    final searchLower = query.toLowerCase();
    // Deduplicate before filtering
    final items = restaurantController.menuItems.toList();
    final seenIds = <int>{};
    final uniqueItems = items.where((item) => seenIds.add(item.id)).toList();

    _filteredItems.value = uniqueItems.where((item) {
      // Search in title
      if (item.title.toLowerCase().contains(searchLower)) return true;

      // Search in description
      if (item.description != null &&
          item.description!.toLowerCase().contains(searchLower)) {
        return true;
      }

      // Search in restaurant name
      if (item.restaurantName != null &&
          item.restaurantName!.toLowerCase().contains(searchLower)) {
        return true;
      }

      // Search in dietary info
      if (item.dietaryInfo != null &&
          item.dietaryInfo!.toLowerCase().contains(searchLower)) {
        return true;
      }

      return false;
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _isSearching.value = false;
    _searchQuery.value = '';
    _updateFilteredItems();
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
        return _buildMenuItemCard(item, index == items.length - 1);
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Get.to(() => MenuItemDetailPage(menuItemId: item.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Item image with badge
                Stack(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildMenuItemImage(item),
                      ),
                    ),
                    if (hasPromotion)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.activePromotions.first.formattedDiscount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Item details
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: ResponsiveText.heading4(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 22,
                        child: hasPromotion
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.activePromotions.first.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: hasPromotion
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        priceText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red,
                                        ),
                                      ),
                                      RotatedBox(
                                        quarterTurns: 1,
                                        child: Text(
                                          originalPriceText ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[400],
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    priceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: TColor.primary,
                                    ),
                                  ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.32,
                            ),
                            child: item.isAvailable
                                ? QuantityCounter(
                                    cartController: cartController,
                                    menuItem: item,
                                    accessToken: userController.isLoggedIn
                                        ? userController.accessToken
                                        : null,
                                    userId: userController.user?.id,
                                    height: 32,
                                    compact: true,
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[400],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: null,
                                    child: const Text('Unavailable'),
                                  ),
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

  Widget _buildMenuItemImage(MenuItem item) {
    String? imageUrl;

    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      imageUrl = item.imageUrl;
    } else if (item.images.isNotEmpty &&
        item.images.first.imageUrl.isNotEmpty) {
      imageUrl = item.images.first.imageUrl;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedImage(
        imageUrl: imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        placeholderIcon: Icons.fastfood,
      );
    }

    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.fastfood, color: Colors.grey[400], size: 40),
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
