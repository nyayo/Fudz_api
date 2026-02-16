import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/models/menu_item.dart';
import 'package:food_delivery_customer_app/models/promo.dart';
import 'package:food_delivery_customer_app/views/screens/promotion_detail_screen.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class PromoBannerWidget extends StatefulWidget {
  final List<MenuItem> featuredItemsWithPromotions;
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

  /// Group items by their promotion and return a list of
  /// {promotion, items, bestImage}
  List<Map<String, dynamic>> get groupedPromotions {
    final Map<int, Map<String, dynamic>> promoMap = {};

    for (final item in widget.featuredItemsWithPromotions) {
      if (!item.hasActivePromotions) continue;

      for (final promo in item.activePromotions) {
        if (!promoMap.containsKey(promo.id)) {
          promoMap[promo.id] = {
            'promotion': promo,
            'items': <MenuItem>[],
            'bestImage': item.hasImage ? item.safeImageUrl : null,
          };
        }
        (promoMap[promo.id]!['items'] as List<MenuItem>).add(item);
        if (promoMap[promo.id]!['bestImage'] == null && item.hasImage) {
          promoMap[promo.id]!['bestImage'] = item.safeImageUrl;
        }
      }
    }

    return promoMap.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _entranceController.forward();
    if (groupedPromotions.isNotEmpty) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(covariant PromoBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (groupedPromotions.isNotEmpty && _timer == null) {
      _startAutoScroll();
    } else if (groupedPromotions.isEmpty) {
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
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      final promos = groupedPromotions;
      if (promos.isEmpty) {
        timer.cancel();
        return;
      }

      if (_currentBanner < promos.length - 1) {
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
    final promo = groupedPromotions[index];
    final promotion = promo['promotion'] as Promotion;
    final items = promo['items'] as List<MenuItem>;

    Get.to(
      () => PromotionDetailScreen(promotion: promotion, items: items),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    final promos = groupedPromotions;

    if (promos.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hot Deals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TColor.primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.deepOrange,
                    size: 22,
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: promos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentBanner = index;
                  });
                },
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  final promotion = promo['promotion'] as Promotion;
                  final items = promo['items'] as List<MenuItem>;
                  final bestImage = promo['bestImage'] as String?;

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page! - index).abs().clamp(
                          0.0,
                          1.0,
                        );
                      }
                      final scale = 1.0 - (value * 0.06);
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF363636),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(70),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Row(
                            children: [
                              // Left side - Text content
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    18,
                                    8,
                                    18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Discount badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${promotion.formattedDiscount} OFF',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Promo name
                                      Text(
                                        promotion.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // Items count + view
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant_menu_rounded,
                                            color: Colors.white.withAlpha(160),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${items.length} items',
                                            style: TextStyle(
                                              color: Colors.white.withAlpha(
                                                160,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(30),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'View all',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Time remaining
                                      if (promotion.endDate.isAfter(
                                        DateTime.now(),
                                      )) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              color: Colors.redAccent.withAlpha(
                                                200,
                                              ),
                                              size: 13,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_getDaysRemaining(promotion.endDate)}d left',
                                              style: TextStyle(
                                                color: Colors.redAccent
                                                    .withAlpha(200),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              // Right side - Food image with curved left edge
                              Expanded(
                                flex: 2,
                                child: ClipPath(
                                  clipper: _LeftCurveClipper(),
                                  child: _buildPromotionImage(bestImage, items),
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
            const SizedBox(height: 12),

            // Page indicators
            if (promos.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(promos.length, (index) {
                  final isActive = _currentBanner == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    width: isActive ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive ? TColor.primary : Colors.grey[300],
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionImage(String? bestImage, List<MenuItem> items) {
    // Try bestImage first, then look through items for any image
    String? imageUrl = bestImage;
    if (imageUrl == null || imageUrl.isEmpty) {
      for (final item in items) {
        if (item.hasImage) {
          imageUrl = item.safeImageUrl;
          break;
        }
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
          ),
          // Subtle left-edge gradient so text doesn't clip into image
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF363636).withAlpha(180),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFF424242),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: Colors.white.withAlpha(50),
          size: 48,
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

/// Custom clipper that curves the left edge of the food image
class _LeftCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start from top-left with an inward curve
    path.moveTo(40, 0);
    // Top edge
    path.lineTo(size.width, 0);
    // Right edge
    path.lineTo(size.width, size.height);
    // Bottom edge
    path.lineTo(40, size.height);
    // Left edge curved inward (concave curve from bottom to top)
    path.quadraticBezierTo(0, size.height * 0.5, 40, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
