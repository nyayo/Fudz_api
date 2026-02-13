import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/main_tab/main_tab_view.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade controller for exit animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeApp() async {
    try {
      print('🚀 Initializing app...');

      // Eagerly trigger RestaurantController so it starts fetching data
      // in parallel with auth check (it uses Get.lazyPut so this is the first access)
      Get.find<RestaurantController>();

      final userController = Get.find<UserController>();

      // Run auth check immediately
      await userController.checkAuthStatus();
      await userController.forceTokenCheck();

      print('🔐 isLoggedIn: ${userController.isLoggedIn}');

      if (userController.isLoggedIn && userController.user != null) {
        print('✅ User is logged in: ${userController.user?.email}');

        // Initialize services in parallel for speed
        _initializeUserServices(userController); // fire-and-forget

        Get.offAll(() => const MainTabView());
      } else {
        print('❌ No valid session, going to login screen');
        Get.offAll(() => const GetStarted());
      }
    } catch (e) {
      print('❌ Error during app initialization: $e');
      Get.offAll(() => const GetStarted());
    }
  }

  Future<void> _initializeUserServices(UserController userController) async {
    try {
      final cartController = Get.find<CartController>();
      final wishlistController = Get.find<WishlistController>();
      final accessToken = userController.accessToken;

      // Run cart and wishlist init in parallel
      await Future.wait([
        cartController.initializeCart(accessToken: accessToken),
        wishlistController.loadWishlist(accessToken),
      ]);

      print('✅ All user services initialized successfully');
    } catch (e) {
      print('⚠️ Error initializing user services: $e');
    }
  }

  Future<bool> _checkTokenValidity(TokenService tokenService) async {
    try {
      final accessToken = await tokenService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        print('❌ No access token found');
        return false;
      }

      // Check if token is expired
      final isExpired = await tokenService.isAccessTokenExpired();
      if (isExpired) {
        print('🔄 Token expired, attempting refresh...');
        final userController = Get.find<UserController>();
        final refreshed = await userController.refreshAuthToken();
        if (!refreshed) {
          print('❌ Token refresh failed');
          await tokenService.clearTokens();
          return false;
        }
        print('✅ Token refreshed successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error checking token validity: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Logo - starts immediately, lasts 1.2s
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  final clampedValue = value.clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: clampedValue,
                    child: Opacity(opacity: clampedValue, child: child),
                  );
                },
                child: Image.asset("assets/logo.png", height: 120, width: 120),
              ),

              const SizedBox(height: 24),

              // Animated App Name - delayed 0.3s, lasts 1.5s
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  // Delay the start by 0.3 seconds (adjust value range)
                  final adjustedValue = (value - 0.15).clamp(0.0, 1.0);
                  final clampedValue = adjustedValue.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: clampedValue,
                    child: Transform.translate(
                      offset: Offset(0, (1 - clampedValue) * 30),
                      child: child,
                    ),
                  );
                },
                child: const Text(
                  'FUDGO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
