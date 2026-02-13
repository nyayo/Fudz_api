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
    with SingleTickerProviderStateMixin {
  int _selectedCategory = 0;
  final CategoryController categoryController = Get.find();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = categoryController.categories;

      if (categories.isEmpty) {
        return _buildLoadingCategories();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Categories",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
              const Spacer(),
              // Debug button - remove in production
              if (kDebugMode)
                IconButton(
                  onPressed: () {
                    categoryController.debugCacheStatus();
                  },
                  icon: const Icon(Icons.bug_report, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryId = category.id;
                final categoryName = category.name;

                // Get image URL with fallback
                final imageUrl = category.mapImageUrl();

                // Stagger animation for entrance effect
                final Animation<double> animation = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      (index / categories.length) * 0.5,
                      0.5 + (index / categories.length) * 0.5,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: animation.value,
                      child: Opacity(
                        opacity: animation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildCategoryCard(
                    context: context,
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
      );
    });
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required int index,
    required int categoryId,
    required String categoryName,
    required String imageUrl,
    required bool isLast,
  }) {
    final isSelected = _selectedCategory == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
        });

        // Preload category details when tapped
        categoryController.getCategoryDetail(categoryId);

        Get.to(
          () => CategoryPage(
            categoryId: categoryId,
            categoryName: categoryName,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 90,
        margin: EdgeInsets.only(
          right: isLast ? 0 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? TColor.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? TColor.primary.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.15),
              spreadRadius: isSelected ? 2 : 1,
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular image container with white background
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.grey[100],
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: ClipOval(
                  child: CachedImage(
                    imageUrl: imageUrl ?? '',
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                    placeholderIcon: Icons.category,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Category name only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                categoryName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : TColor.primaryText,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Categories",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: TColor.primaryText,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 90,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
