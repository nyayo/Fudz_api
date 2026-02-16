import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/category_controller.dart';
import 'package:food_delivery_customer_app/views/screens/category_page.dart';
import 'package:food_delivery_customer_app/views/widgets/cached_image_widget.dart';

import 'package:get/get.dart';

class CategoriesWidget extends StatefulWidget {
  const CategoriesWidget({super.key});

  @override
  State<CategoriesWidget> createState() => _CategoriesWidgetState();
}

class _CategoriesWidgetState extends State<CategoriesWidget>
    with TickerProviderStateMixin {
  int _selectedCategory = 0;
  final CategoryController categoryController = Get.find();
  late AnimationController _entranceController;
  late AnimationController _bounceController;
  late ScrollController _scrollController;
  int _lastCategoryCount = 0;

  static const double _itemWidth = 88.0;
  static const double _itemSpacing = 12.0;
  static const double _horizontalPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _entranceController.dispose();
    _bounceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Detect which category is in the center of the viewport while scrolling
  void _onScroll() {
    if (!_scrollController.hasClients || _lastCategoryCount == 0) return;

    final viewportWidth = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;

    // The center of the visible area in scroll-content coordinates
    final centerOfViewport =
        scrollOffset + (viewportWidth / 2) - _horizontalPadding;

    // Calculate which item index falls at that center point
    final totalItemWidth = _itemWidth + _itemSpacing;
    int centerIndex = (centerOfViewport / totalItemWidth).round();
    centerIndex = centerIndex.clamp(0, _lastCategoryCount - 1);

    if (centerIndex != _selectedCategory) {
      setState(() {
        _selectedCategory = centerIndex;
      });
      _bounceController.forward(from: 0.0);
    }
  }

  void _onCategoryTap(int index, int categoryId, String categoryName) {
    setState(() {
      _selectedCategory = index;
    });
    _bounceController.forward(from: 0.0);
    _scrollToCenter(index);

    // Navigate
    categoryController.getCategoryDetail(categoryId);
    Get.to(
      () => CategoryPage(categoryId: categoryId, categoryName: categoryName),
    );
  }

  void _scrollToCenter(int index) {
    if (!_scrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * (_itemWidth + _itemSpacing)) -
        (screenWidth / 2) +
        (_itemWidth / 2) +
        _horizontalPadding;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = categoryController.categories;

      if (categories.isEmpty) {
        return _buildLoadingCategories();
      }

      _lastCategoryCount = categories.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: TColor.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Categories",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: TColor.primaryText,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (kDebugMode)
                  IconButton(
                    onPressed: () {
                      categoryController.debugCacheStatus();
                    },
                    icon: const Icon(Icons.bug_report, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Curved shelf background + categories
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                // Curved shelf background
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 100),
                    painter: _ShelfPainter(),
                  ),
                ),

                // Category items
                Positioned.fill(
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: _horizontalPadding,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category.id;
                      final categoryName = category.name;
                      final imageUrl = category.mapImageUrl();

                      // Staggered entrance animation
                      final entrance = Tween<double>(begin: 0.0, end: 1.0)
                          .animate(
                            CurvedAnimation(
                              parent: _entranceController,
                              curve: Interval(
                                (index / categories.length) * 0.4,
                                0.4 + (index / categories.length) * 0.6,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          );

                      return AnimatedBuilder(
                        animation: entrance,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - entrance.value)),
                            child: Opacity(
                              opacity: entrance.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCategoryItem(
                          index: index,
                          categoryId: categoryId,
                          categoryName: categoryName,
                          imageUrl: imageUrl ?? '',
                          isLast: index == categories.length - 1,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCategoryItem({
    required int index,
    required int categoryId,
    required String categoryName,
    required String imageUrl,
    required bool isLast,
  }) {
    final isSelected = _selectedCategory == index;

    // Circle sizes — bigger pop on selected
    final double circleSize = isSelected ? 100 : 80;
    final double imageSize = isSelected ? 70 : 50;

    return GestureDetector(
      onTap: () => _onCategoryTap(index, categoryId, categoryName),
      child: Container(
        width: _itemWidth,
        margin: EdgeInsets.only(right: isLast ? 0 : _itemSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Animated circle with image — bounce scale on selection
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.88,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? TColor.primary.withValues(alpha: 0.30)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: isSelected ? 18 : 10,
                      spreadRadius: isSelected ? 3 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isSelected
                        ? TColor.primary.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.12),
                    width: isSelected ? 3 : 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: imageSize,
                    height: imageSize,
                    child: ClipOval(
                      child: CachedImage(
                        imageUrl: imageUrl,
                        width: imageSize,
                        height: imageSize,
                        borderRadius: imageSize / 2,
                        placeholderIcon: Icons.category,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Category name
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: isSelected ? 13 : 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? TColor.primaryText : TColor.secondaryText,
                letterSpacing: isSelected ? 0.2 : 0,
              ),
              child: Text(
                categoryName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 6),

            // Selection indicator pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 28 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: TColor.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 100,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: Duration(milliseconds: 800 + (index * 150)),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Container(
                  width: 88,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 56,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Paints a subtle curved shelf behind the category items
class _ShelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.withValues(alpha: 0.04),
          Colors.grey.withValues(alpha: 0.08),
          Colors.grey.withValues(alpha: 0.03),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height * 0.45);
    path.quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.45);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
