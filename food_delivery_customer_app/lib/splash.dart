import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/services/performance_tracker.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/main_tab/main_tab_view.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    final perf = Get.find<PerformanceTracker>();

    try {
      perf.start('Total Startup');
      print('🚀 Initializing app...');

      // 1. Get RestaurantController (non-blocking now - uses cache-first)
      //    It loads from cache instantly, then syncs API in background
      perf.start('RestaurantController init');
      Get.find<RestaurantController>();
      perf.end('RestaurantController init');

      // 2. Auth check - fast check from cache, optional background refresh
      perf.start('Auth check');
      final userController = Get.find<UserController>();
      userController.checkAuthStatusFromCache(); // Fast cache-only check
      perf.end('Auth check');

      // Get login status from cache (instant)
      final isLoggedIn = userController.isLoggedIn;
      print('🔐 isLoggedIn: $isLoggedIn');

      perf.end('Total Startup');
      perf.finishStartup();

      // Delay navigation to after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isLoggedIn && userController.user != null) {
          print('✅ User is logged in: ${userController.user?.email}');

          // Fire-and-forget: user services in background (don't block navigation)
          _initializeUserServices(userController).catchError((e) {
            print('⚠️ User services error: $e');
          });

          Get.offAll(() => const MainTabView());
        } else {
          print('❌ No valid session, going to login screen');
          Get.offAll(() => const GetStarted());
        }
      });
    } catch (e, stackTrace) {
      print('❌ Error during app initialization: $e');
      print('Stack trace: $stackTrace');
      perf.end('Total Startup', success: false, error: '$e');
      perf.finishStartup();
      
      // Navigate to login on error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const GetStarted());
      });
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/logo.png", height: 120, width: 120),
            const SizedBox(height: 24),
            const Text(
              'FUDGO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
