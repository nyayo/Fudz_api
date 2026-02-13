import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/promo.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class PromoBannerWidget extends StatefulWidget {
  final List<MenuItem>
  featuredItemsWithPromotions; // This should be the parameter name
  final VoidCallback? onBannerTap;

  const PromoBannerWidget({
    super.key,
    required this.featuredItemsWithPromotions, // Make sure this matches
    this.onBannerTap,
  });

  @override
  State<PromoBannerWidget> createState() => _PromoBannerWidgetState();
}

class _PromoBannerWidgetState extends State<PromoBannerWidget> {
  int _currentBanner = 0;
  final PageController _pageController = PageController();
  Timer? _timer;

  List<Map<String, dynamic>> get banners {
    return widget.featuredItemsWithPromotions
        .where((item) => item.hasActivePromotions)
        .map((item) {
          final activePromotions = item.activePromotions;
          final highestPromo = activePromotions.reduce(
            (a, b) => a.discount > b.discount ? a : b,
          );

          return {
            'menuItem': item,
            'promotion': highestPromo,
            'image': item.safeImageUrl,
            'title': '${highestPromo.formattedDiscount} OFF: ${item.title}',
            'subtitle': highestPromo.name,
            'originalPrice': item.formattedPrice,
            'discountedPrice': item.formattedDiscountedPrice,
          };
        })
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (banners.isNotEmpty) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(covariant PromoBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (banners.isNotEmpty && _timer == null) {
      _startAutoScroll();
    } else if (banners.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (banners.isEmpty) {
        timer.cancel();
        return;
      }

      if (_currentBanner < banners.length - 1) {
        _currentBanner++;
      } else {
        _currentBanner = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentBanner,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onBannerTap(int index) {
    final banner = banners[index];
    final menuItem = banner['menuItem'] as MenuItem;

    if (widget.onBannerTap != null) {
      widget.onBannerTap!();
    } else {
      // Navigate to menu item details
      Get.toNamed('/menu-item-details', arguments: menuItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            onPageChanged: (index) {
              setState(() {
                _currentBanner = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = banners[index];
              final menuItem = banner['menuItem'] as MenuItem;
              final promotion = banner['promotion'] as Promotion;

              return GestureDetector(
                onTap: () => _onBannerTap(index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Background Image
                        if (menuItem.hasImage)
                          Image.network(
                            menuItem.safeImageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.fastfood,
                                  color: Colors.grey,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: TColor.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.fastfood,
                              color: Colors.grey,
                              size: 50,
                            ),
                          ),

                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),

                        // Promotion Content
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Promotion Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: TColor.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  banner['subtitle'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Promotion Title
                              Builder(
                                builder: (context) => Text(
                                  banner['title'] as String,
                                  style: ResponsiveText.heading4(
                                    context,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Price Information
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) => Text(
                                      banner['discountedPrice'] as String,
                                      style: ResponsiveText.heading3(
                                        context,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (context) => Text(
                                      banner['originalPrice'] as String,
                                      style: ResponsiveText.bodySmall(
                                        context,
                                        color: Colors.white.withOpacity(0.7),
                                      ).copyWith(decoration: TextDecoration.lineThrough),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Time Remaining Badge (optional)
                        if (promotion.endDate.isAfter(DateTime.now()))
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Builder(
                                builder: (context) => Text(
                                  '${_getDaysRemaining(promotion.endDate)}d left',
                                  style: ResponsiveText.tiny(
                                    context,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Banner Indicators
        if (banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentBanner == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentBanner == index
                      ? TColor.primary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
      ],
    );
  }

  int _getDaysRemaining(DateTime endDate) {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays;
  }
}
