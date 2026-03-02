import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/category_controller.dart';
import 'package:food_delivery_customer_app/controller/email_auth_controller.dart';
import 'package:food_delivery_customer_app/controller/location_controller.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/controller/promotion_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/firebase_options.dart';
import 'package:food_delivery_customer_app/services/connectivity_service.dart';
import 'package:food_delivery_customer_app/services/notification_service.dart';
import 'package:food_delivery_customer_app/routes/app_pages.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/error_logger_service.dart';
import 'package:food_delivery_customer_app/services/google.dart';
import 'package:food_delivery_customer_app/services/image_precache_service.dart';
import 'package:food_delivery_customer_app/services/performance_tracker.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:food_delivery_customer_app/controller/menu_controller.dart'
    as men;
import 'package:food_delivery_customer_app/splash.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase and local notifications for the background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal initialization for background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await GetStorage.init();

  print('📱 Terminated/Background message received: ${message.messageId}');

  // We need to initialize local notifications because this is a separate isolate
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // We can't easily use the full NotificationService here because it depends on GetX controllers
  // which aren't available in background. So we show a simple notification.
  final notification = message.notification;
  final data = message.data;

  // CRITICAL FIX: To avoid duplication, only show a manual local notification
  // if THERE IS NO notification payload (data-only message).
  // If there is a notification payload, the OS (FCM) already shows it automatically in background/terminated.
  if (notification == null) {
    print('📱 Data-only background message: showing manual notification');
    final String title =
        data['title']?.toString() ?? data['name']?.toString() ?? 'Fudgo';
    final String body =
        data['body']?.toString() ??
        data['description']?.toString() ??
        data['message']?.toString() ??
        '';

    if (title.isNotEmpty || body.isNotEmpty) {
      // Determine channel based on message type
      String channelId = 'order_notifications_v1';
      String channelName = 'Order Updates';

      final type = data['type']?.toString().toLowerCase() ?? '';
      if (type.contains('promotion') || type == 'new_promotion') {
        channelId = 'promo_notifications_v2';
        channelName = 'Promotions & Offers';
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformChannelSpecifics,
        payload: json.encode(data),
      );
    }
  } else {
    print('📱 Notification background message: letting FCM handle display');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize GetStorage
    await GetStorage.init();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // CRITICAL: Register background handler as early as possible (before runApp)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    runApp(const MyApp());
  } catch (e) {
    print('Error during initialization: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notification service after app starts
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    // Small delay to ensure all bindings are loaded
    await Future.delayed(const Duration(milliseconds: 100));
    final notificationService = Get.find<NotificationService>();
    await notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fudgo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 350),
      initialBinding: AppBindings(),
      home: const SplashScreen(),
      getPages: AppPages.routes,
    );
  }
}

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register ERROR LOGGER FIRST so all other services can use it
    Get.put(ErrorLoggerService(), permanent: true);

    // Register PERFORMANCE TRACKER for startup diagnostics
    Get.put(PerformanceTracker(), permanent: true);

    // Register connectivity service
    Get.put(ConnectivityService(), permanent: true);

    // Register services FIRST
    Get.lazyPut(() => ApiService(), fenix: true);
    Get.put(TokenService(), permanent: true);
    Get.put(GoogleSignInService());

    // THEN register NotificationService (it needs ApiService)
    Get.put(NotificationService(), permanent: true);

    // Register controllers
    Get.lazyPut(() => UserController(), fenix: true);
    Get.lazyPut(() => RestaurantController(), fenix: true);
    Get.lazyPut(() => CartController(), fenix: true);
    Get.lazyPut(() => CategoryController(), fenix: true);
    Get.lazyPut(() => WishlistController(), fenix: true);
    Get.lazyPut(() => OrderController(), fenix: true);
    Get.lazyPut(() => EmailAuthController(), fenix: true);
    Get.lazyPut(() => men.MenuItemController(), fenix: true);
    Get.lazyPut(() => LocationController(), fenix: true);
    Get.lazyPut(() => PromotionController(), fenix: true);

    // Background image pre-caching service
    Get.put(ImagePreCacheService(), permanent: true);
  }
}
