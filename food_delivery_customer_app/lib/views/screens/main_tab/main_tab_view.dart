// lib/views/screens/main_tab/main_tab_view.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/views/screens/Home_view/homescreen.dart';
import 'package:food_delivery_customer_app/views/screens/account.dart';
import 'package:food_delivery_customer_app/views/screens/cart.dart';
import 'package:food_delivery_customer_app/views/screens/wishlist_page.dart';

import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;
  final CartController _cartController = Get.find<CartController>();

  final List<Widget> _pages = [
    const HomePage(),
    WishlistPage(),
    const CartPage(), // Cart is now at index 2 (replacing Order)
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home_outlined, "Home", 0),
              _buildWishlistNavItem(Icons.favorite_border, "WishList", 1),
              _buildCartNavItem(), // Cart with badge
              _buildNavItem(Icons.person_outline, "Profile", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == 1;
    final wishlistController = Get.find<WishlistController>();

    return GestureDetector(
      onTap: () => _onItemTapped(1),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 24 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? TColor.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  color: isSelected ? Colors.white : Colors.black54,
                  size: 26,
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Builder(
                      builder: (context) => Text(
                        "WishList",
                        style: ResponsiveText.bodySmall(
                          context,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Wishlist badge
          Positioned(
            right: isSelected ? 8 : 4,
            top: 8,
            child: GetBuilder<WishlistController>(
              builder: (controller) {
                final itemCount = controller.wishlistItemCount;
                if (itemCount == 0) return const SizedBox();

                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Builder(
                    builder: (context) => Text(
                      itemCount > 9 ? '9+' : itemCount.toString(),
                      style: ResponsiveText.tiny(
                        context,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 24 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? TColor.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black54,
              size: 26,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Builder(
                  builder: (context) => Text(
                    label,
                    style: ResponsiveText.bodySmall(
                      context,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartNavItem() {
    final bool isSelected = _selectedIndex == 2;
    final cartController = Get.find<CartController>();

    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 24 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? TColor.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: isSelected ? Colors.white : Colors.black54,
                  size: 26,
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Builder(
                      builder: (context) => Text(
                        "Cart",
                        style: ResponsiveText.bodySmall(
                          context,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Cart badge - Use GetBuilder to ensure it rebuilds
          Positioned(
            right: isSelected ? 8 : 4,
            top: 8,
            child: GetBuilder<CartController>(
              builder: (controller) {
                final itemCount = controller.cartItemCount;
                if (itemCount == 0) return const SizedBox();

                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Builder(
                    builder: (context) => Text(
                      itemCount > 9 ? '9+' : itemCount.toString(),
                      style: ResponsiveText.tiny(
                        context,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
