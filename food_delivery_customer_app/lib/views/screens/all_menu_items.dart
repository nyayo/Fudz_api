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
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';

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
  final RxList<_CategoryOption> _categories = <_CategoryOption>[].obs;
  final RxInt _selectedCategoryId = (-1).obs;

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
        _applyFilters();
      }
    });

    // Seed initial filtered items
    _applyFilters();

    // Scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isSearching.value) {
        restaurantController.getMenuItems(loadMore: true);
      }
    });
  }

  void _applyFilters() {
    // Deduplicate by ID before setting
    final items = restaurantController.menuItems.toList();
    final seenIds = <int>{};
    final uniqueItems = items.where((item) => seenIds.add(item.id)).toList();
    _rebuildCategories(uniqueItems);

    final query = _searchQuery.value.trim().toLowerCase();
    final selectedCategoryId = _selectedCategoryId.value;

    _filteredItems.value = uniqueItems.where((item) {
      if (selectedCategoryId != -1 && item.category != selectedCategoryId) {
        return false;
      }

      if (query.isEmpty) return true;

      if (item.title.toLowerCase().contains(query)) return true;
      if (item.description != null &&
          item.description!.toLowerCase().contains(query)) {
        return true;
      }
      if (item.restaurantName != null &&
          item.restaurantName!.toLowerCase().contains(query)) {
        return true;
      }
      if (item.dietaryInfo != null &&
          item.dietaryInfo!.toLowerCase().contains(query)) {
        return true;
      }

      return false;
    }).toList();
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
      _applyFilters();
      return;
    }

    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _isSearching.value = false;
    _searchQuery.value = '';
    _applyFilters();
  }

  void _rebuildCategories(List<MenuItem> items) {
    final categoryMap = <int, String>{};
    for (final item in items) {
      final name = item.categoryName ?? 'Category ${item.category}';
      categoryMap.putIfAbsent(item.category, () => name);
    }

    final options = [
      const _CategoryOption(id: -1, name: 'All'),
      ...categoryMap.entries.map(
        (entry) => _CategoryOption(id: entry.key, name: entry.value),
      ),
    ];

    _categories.value = options;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: TColor.primaryText,
                          ),
                        ),
                        
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSearchField(),
                    const SizedBox(height: 14),
                    _buildCategoryChips(),
                  ],
                ),
              ),
            ),
          ),

          Obx(() {
            if (_searchQuery.value.isNotEmpty) {
              return SliverToBoxAdapter(
                child: _buildSearchResultsInfo(context),
              );
            }
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Text(
                  'Popular',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TColor.primaryText,
                  ),
                ),
              ),
            );
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
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey[500], size: 16),
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
                icon: Icon(Icons.clear, color: Colors.grey[500], size: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF8F9FA),
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
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return FadeSlideIn(
            delay: Duration(milliseconds: 40 * (index % 6)),
            slideOffset: const Offset(0, 0.08),
            child: _buildMenuItemCard(item),
          );
        }, childCount: items.length),
      ),
    );
  }

  // Update the _buildMenuItemCard method in AllMenuItemsPage

  Widget _buildMenuItemCard(MenuItem item) {
    final bool hasPromotion = item.hasActivePromotions;
    final String priceText = hasPromotion
        ? item.formattedDiscountedPrice
        : item.formattedPrice;
    final String? originalPriceText = hasPromotion ? item.formattedPrice : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _PressScale(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    SmoothPageRoute(
                      page: MenuItemDetailPage(menuItemId: item.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: ClipOval(child: _buildMenuItemImage(item)),
                            ),
                            if (hasPromotion)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    item
                                        .activePromotions
                                        .first
                                        .formattedDiscount,
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
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TColor.primaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    hasPromotion ? Colors.red : TColor.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (originalPriceText != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                originalPriceText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: 0,
              right: 0,
              child: Center(child: _buildAddButton(item)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(MenuItem item) {
    return Obx(() {
      final isInCart = cartController.isItemInCart(item.id);
      final isEnabled =
          userController.isLoggedIn &&
          item.isAvailable &&
          !cartController.isItemProcessing('${item.id}_add');

      if (isInCart) {
        return QuantityCounter(
          cartController: cartController,
          menuItem: item,
          accessToken: userController.isLoggedIn
              ? userController.accessToken
              : null,
          userId: userController.user?.id,
          height: 32,
          compact: true,
        );
      }

      return SizedBox(
        width: 40,
        height: 40,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? TColor.primary : Colors.grey[300],
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 2,
          ),
          onPressed: isEnabled
              ? () async {
                  await cartController.addToCart(
                    menuItem: item,
                    quantity: 1,
                    accessToken: userController.accessToken,
                    userId: userController.user?.id,
                  );
                }
              : null,
          child: const Icon(Icons.add, size: 20, color: Colors.white),
        ),
      );
    });
  }

  Widget _buildCategoryChips() {
    return Obx(() {
      if (_categories.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategoryId.value == category.id;

            return GestureDetector(
              onTap: () {
                _selectedCategoryId.value = category.id;
                _applyFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? TColor.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? TColor.primary : Colors.grey[200]!,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: TColor.primary.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
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

class _CategoryOption {
  final int id;
  final String name;

  const _CategoryOption({required this.id, required this.name});
}

class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
