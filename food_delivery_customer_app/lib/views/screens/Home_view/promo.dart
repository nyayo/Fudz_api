import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/promo.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class PromoBannerWidget extends StatefulWidget {
  final List<MenuItem>
  featuredItemsWithPromotions;
  final VoidCallback? onBannerTap;

  const PromoBannerWidget({
    super.key,
    required this.featuredItemsWithPromotions,
    this.onBannerTap,
  });

  @override
  State<PromoBannerWidget> createState() => _PromoBannerWidgetState();
}

class _PromoBannerWidgetState extends State<PromoBannerWidget>
    with SingleTickerProviderStateMixin {
  int _currentBanner = 0;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  late AnimationController _entranceController;

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
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _entranceController.forward();
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
    _entranceController.dispose();
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
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
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
      Get.toNamed('/menu-item-details', arguments: menuItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
        )),
        child: Column(
          children: [
            SizedBox(
              height: 190,
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

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page! - index).abs().clamp(0.0, 1.0);
                      }
                      final scale = 1.0 - (value * 0.08);
                      final opacity = 1.0 - (value * 0.3);

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () => _onBannerTap(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Background Image
                              if (menuItem.hasImage)
                                Positioned.fill(
                                  child: Image.network(
                                    menuItem.safeImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.fastfood_rounded,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  color: TColor.primary.withAlpha(25),
                                  child: const Icon(
                                    Icons.fastfood_rounded,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                ),

                              // Gradient Overlay — darker and more premium
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [
                                      Colors.black.withAlpha(20),
                                      Colors.black.withAlpha(100),
                                      Colors.black.withAlpha(180),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),

                              // Content
                              Positioned(
                                bottom: 18,
                                left: 18,
                                right: 18,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Promo badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            TColor.primary,
                                            TColor.primary.withAlpha(200),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: TColor.primary.withAlpha(60),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        banner['subtitle'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Title
                                    Builder(
                                      builder: (context) => Text(
                                        banner['title'] as String,
                                        style: ResponsiveText.heading4(
                                          context,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    // Price row
                                    Row(
                                      children: [
                                        Builder(
                                          builder: (context) => Text(
                                            banner['discountedPrice'] as String,
                                            style: ResponsiveText.heading3(
                                              context,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Builder(
                                          builder: (context) => Text(
                                            banner['originalPrice'] as String,
                                            style: ResponsiveText.bodySmall(
                                              context,
                                              color: Colors.white.withAlpha(150),
                                            ).copyWith(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              decorationColor:
                                                  Colors.white.withAlpha(150),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Time remaining badge
                              if (promotion.endDate.isAfter(DateTime.now()))
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF1744),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withAlpha(50),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Builder(
                                          builder: (context) => Text(
                                            '${_getDaysRemaining(promotion.endDate)}d left',
                                            style: ResponsiveText.tiny(
                                              context,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Page indicators — pill style
            if (banners.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (index) {
                  final isActive = _currentBanner == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    width: isActive ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? TColor.primary
                          : Colors.grey[300],
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: TColor.primary.withAlpha(40),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  int _getDaysRemaining(DateTime endDate) {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays;
  }
}
