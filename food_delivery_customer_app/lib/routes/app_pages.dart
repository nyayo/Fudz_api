import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/auth/email_login.dart';
import 'package:food_delivery_customer_app/views/auth/email_verification_screen.dart';
import 'package:food_delivery_customer_app/views/auth/login.dart';
import 'package:food_delivery_customer_app/views/screens/error_log_viewer.dart';
import 'package:food_delivery_customer_app/views/screens/get_started.dart';
import 'package:food_delivery_customer_app/views/screens/google_phone_input.dart';
import 'package:food_delivery_customer_app/views/screens/main_tab/main_tab_view.dart';
import 'package:food_delivery_customer_app/views/screens/promotions_page.dart';
import 'package:food_delivery_customer_app/views/screens/register.dart';
import 'package:get/get.dart';

class AppPages {
  static final routes = [
    GetPage(name: '/get_started', page: () => const GetStarted()),
    GetPage(name: '/login', page: () => LoginScreen()),
    GetPage(name: '/email_login_screen', page: () => const EmailLoginScreen()),
    GetPage(
      name: '/email_verification',
      page: () => const EmailVerificationScreen(),
    ),
    GetPage(name: '/register', page: () => RegistrationPage()),
    GetPage(name: '/home', page: () => const MainTabView()),
    GetPage(name: '/promotions', page: () => const PromotionsPage()),
    GetPage(name: '/promotion-details/:id', page: () => const MainTabView()),
    // In your routes file
    GetPage(
      name: '/google_phone_input',
      page: () {
        final arguments = Get.arguments;
        if (arguments is Map<String, dynamic>) {
          return GooglePhoneInputScreen(googleUserData: arguments);
        }
        return const Scaffold(body: Center(child: Text('Invalid arguments')));
      },
    ),
    GetPage(name: '/error_log_viewer', page: () => const ErrorLogViewer()),
  ];
}
