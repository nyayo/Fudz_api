import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../controller/order_controller.dart';
import '../controller/promotion_controller.dart';
import '../controller/user_controller.dart';
import '../services/api_service.dart';
import '../constants/colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final GetStorage _storage = GetStorage();

  ApiService get _apiService => Get.find<ApiService>();
  UserController? _userController;
  OrderController? _orderController;

  // Notification channels (V1 to reset sound settings)
  static const String _orderChannelId = 'order_notifications_v1';
  static const String _orderChannelName = 'Order Updates';
  static const String _orderChannelDesc =
      'Notifications about your food orders';

  static const String _promoChannelId = 'promo_notifications_v2';
  static const String _promoChannelName = 'Promotions & Offers';
  static const String _promoChannelDesc = 'Special offers and promotions';

  static const String _systemChannelId = 'system_notifications_v1';
  static const String _systemChannelName = 'System Updates';
  static const String _systemChannelDesc =
      'App updates and system notifications';

  // Stream controllers for notification events
  final StreamController<Map<String, dynamic>> _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStream.stream;

  // For foreground notifications
  final RxBool _hasNewNotification = false.obs;
  bool get hasNewNotification => _hasNewNotification.value;
  set hasNewNotification(bool value) => _hasNewNotification.value = value;

  // Store unread notifications
  final RxList<Map<String, dynamic>> _notifications =
      <Map<String, dynamic>>[].obs;
  List<Map<String, dynamic>> get notifications => _notifications.toList();
  int get unreadCount => _notifications.where((n) => n['read'] == false).length;

  Future<void> initialize() async {

    try {
      print('🔄 Initializing Notification Service...');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Get FCM token
      await _setupFCMToken();

      // Configure Firebase messaging
      await _configureFirebaseMessaging();

      // Load saved notifications
      await _loadSavedNotifications();

      // Subscribe to general topics
      await subscribeToTopic('promotions');

      print('✅ Notification Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Notification Service: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            // ios: initializationSettingsIOS,
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels (Android 8.0+)
      await _createNotificationChannels();

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      // Order notifications channel (high importance)
      final AndroidNotificationChannel orderChannel =
          AndroidNotificationChannel(
            _orderChannelId,
            _orderChannelName,
            description: _orderChannelDesc,
            importance: Importance.max,
            playSound: true,
            // sound: const RawResourceAndroidNotificationSound('notification'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList(const [0, 500, 1000, 500]),
            showBadge: true,
          );

      // Promotions channel (High importance with sound)
      final AndroidNotificationChannel promoChannel =
          AndroidNotificationChannel(
            _promoChannelId,
            _promoChannelName,
            description: _promoChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

      // System notifications channel (low importance)
      const AndroidNotificationChannel systemChannel =
          AndroidNotificationChannel(
            _systemChannelId,
            _systemChannelName,
            description: _systemChannelDesc,
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(orderChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(promoChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(systemChannel);

      print('✅ Notification channels created');
    } catch (e) {
      print('❌ Error creating notification channels: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Request notification permission for Android 13+
        final bool? granted = await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();

        if (granted == true) {
          print('✅ Android notification permission granted');
        }
      }

      // Request Firebase permissions
      final NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            announcement: false,
          );

      print('Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }

  Future<void> _setupFCMToken() async {
    try {
      // Get token
      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');

        // Save token locally
        _storage.write('fcm_token', token);

        // Send token to backend if user is logged in
        await _sendTokenToBackend(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _storage.write('fcm_token', newToken);
        _sendTokenToBackend(newToken);
      });

      print('✅ FCM token setup completed');
    } catch (e) {
      print('❌ Error setting up FCM token: $e');
    }
  }

  /// Public method to register device token with backend after user login
  /// This should be called after user successfully logs in
  Future<void> registerDeviceToken() async {
    try {
      final String? token = _storage.read('fcm_token') ?? await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 Registering device token with backend...');
        await _sendTokenToBackend(token);
      } else {
        print('⚠️ No FCM token available to register');
      }
    } catch (e) {
      print('❌ Error registering device token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final userController = Get.find<UserController>();
      if (userController.isLoggedIn) {
        await _apiService.post('users/auth/device/register/', {
          'registration_id': token,
          'type': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios',
          'name': 'Customer Device',
        });
        print('✅ FCM token sent to backend successfully');
      } else {
        print('⚠️ User not logged in, skipping token registration');
      }
    } catch (e) {
      print('❌ Error sending FCM token to backend: $e');
    }
  }


  Future<void> _configureFirebaseMessaging() async {
    try {
      // Handle messages in foreground

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('═══════════════════════════════════════════════════════');
        print('📱 FOREGROUND MESSAGE RECEIVED');
        print('   Message ID: ${message.messageId}');
        print('   Notification Title: ${message.notification?.title}');
        print('   Data: ${message.data}');
        print('═══════════════════════════════════════════════════════');

        // Extract info
        final notification = message.notification;
        final data = message.data;
        final String title = notification?.title ?? data['title']?.toString() ?? 'Food Delivery';
        final String body = notification?.body ?? data['body']?.toString() ?? '';

        // 1. Show local notification (standard system heads-up)
        // This is necessary in foreground because FCM doesn't show it automatically
        _showLocalNotification(message);

        // 2. Process notification (updates local lists and controllers)
        _processNotification(message.data);
      });



      // Handle when app is opened from background via notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from background via notification');
        _handleNotificationTap(message.data);
      });

      // Check if app was opened from terminated state via notification
      final RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        print('📱 App opened from terminated state via notification');
        Future.delayed(const Duration(seconds: 2), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // Set foreground notification options for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      print('✅ Firebase Messaging configured');
    } catch (e) {
      print('❌ Error configuring Firebase Messaging: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      // Extract title and body from notification payload OR data payload
      // This ensures notifications work in foreground even with data-only messages
      final String title = notification?.title ?? 
          data['title']?.toString() ?? 
          data['name']?.toString() ??
          'Food Delivery';
      final String body = notification?.body ?? 
          data['body']?.toString() ?? 
          data['description']?.toString() ??
          data['message']?.toString() ??
          '';

      // Custom Logic: Show item names if available
      String displayBody = body;
      String displayTitle = title;
      
      try {
        if (data['items'] != null) {
          String itemsStr = data['items'].toString();
          List<String> itemNames = [];
          
          // Try to decode if it looks like JSON
          if (itemsStr.startsWith('[') && itemsStr.endsWith(']')) {
             try {
               final List<dynamic> decoded = json.decode(itemsStr);
               itemNames = decoded.map((e) {
                 if (e is Map) return e['name'].toString();
                 return e.toString();
               }).toList();
             } catch (e) {
               // Fallback if decode fails, treat as simple string
               itemNames = [itemsStr];
             }
          } else {
            // Not JSON, maybe comma separated or just text
            itemNames = [itemsStr];
          }
          
          if (itemNames.isNotEmpty) {
             final itemsList = itemNames.join(', ');
             // Keep the status/message if it exists, or format nicely
             if (displayBody.isNotEmpty) {
               displayBody = '$displayBody\nItems: $itemsList';
             } else {
               displayBody = 'Items: $itemsList';
             }
          }
        }
      } catch (e) {
        print('Error parsing notification items: $e');
      }

      
      // Skip if we have no meaningful content to show
      if (title == 'Food Delivery' && body.isEmpty) {
        print('⚠️ Skipping notification with no content');
        return;
      }

      // Determine which channel to use based on notification type
      String channelId = _orderChannelId;
      final rawType = data['type']?.toString().toLowerCase() ?? '';
      final hasPromoId = data['promotion_id'] != null;
      final type = (rawType.isEmpty && hasPromoId) ? 'promotion' : rawType;
      
      if (type.contains('promotion') || type == 'new_promotion') {
        channelId = _promoChannelId;
      } else if (type == 'system') {
        channelId = _systemChannelId;
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            _getChannelName(channelId),
            channelDescription: _getChannelDesc(channelId),
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            styleInformation: BigTextStyleInformation(displayBody),
            playSound: true,
            // sound: channelId == _orderChannelId 
            //     ? const RawResourceAndroidNotificationSound('notification')
            //     : null,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
            colorized: true,

            color: TColor.primary,
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher',
            ),
          );

      final DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      // Generate a unique ID for the notification
      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notificationId,
        displayTitle,
        displayBody,
        platformChannelSpecifics,
        payload: json.encode(data),
      );

      print('✅ Local notification shown: $title');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }


  String _getChannelName(String channelId) {
    switch (channelId) {
      case _orderChannelId:
        return _orderChannelName;
      case _promoChannelId:
        return _promoChannelName;
      case _systemChannelId:
        return _systemChannelName;
      default:
        return _orderChannelName;
    }
  }

  String _getChannelDesc(String channelId) {
    switch (channelId) {
      case _orderChannelId:
        return _orderChannelDesc;
      case _promoChannelId:
        return _promoChannelDesc;
      case _systemChannelId:
        return _systemChannelDesc;
      default:
        return _orderChannelDesc;
    }
  }

  void _processNotification(
    Map<String, dynamic> data, {
    bool fromBackground = false,
  }) {
    try {
      print('═══════════════════════════════════════════════════');
      print('🔔 PROCESSING NOTIFICATION');
      print('   From background: $fromBackground');
      print('   Data: $data');
      
      final String rawType = data['type']?.toString().toLowerCase() ?? '';
      final bool hasPromoId = data['promotion_id'] != null;
      final String type = (rawType.isEmpty && hasPromoId) ? 'promotion' : (rawType.isEmpty ? 'order' : rawType);
      
      print('   Detected type: $type');
      print('   Raw type: $rawType');
      print('   Has promotion_id: $hasPromoId');
      
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': data['title'] ?? data['name'] ?? 'New Offer!',
        'body': data['body'] ?? data['description'] ?? data['message'] ?? '',
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
        'type': type.contains('promotion') ? 'promotion' : type,
      };

      // Add to notifications list
      _notifications.insert(0, notification);
      print('✅ Added notification to list (total: ${_notifications.length})');

      // Update badge count
      _hasNewNotification.value = true;

      // Save to storage
      try {
        _saveNotifications();
        print('✅ Saved notifications to storage');
      } catch (e) {
        print('❌ Error saving notifications: $e');
      }

      // Update order controller if this is an order notification
      if (data['type'] == 'order_update') {
        print('📦 Order notification detected, updating order controller...');
        try {
          _updateOrderController(data);
        } catch (e) {
          print('❌ Error updating order controller: $e');
        }
      }

      // Update promotion controller if this is a promotion notification
      if (type.contains('promotion') || type == 'new_promotion') {
        print('🎁 PROMOTION NOTIFICATION DETECTED!');
        print('   Type contains "promotion": ${type.contains('promotion')}');
        print('   Type equals "new_promotion": ${type == 'new_promotion'}');
        
        try {
          _updatePromotionController(data);
        } catch (e, stackTrace) {
          print('❌ ERROR updating promotion controller:');
          print('   Error: $e');
          print('   Stack trace: $stackTrace');
        }
      } else {
        print('ℹ️  Not a promotion notification (type: $type)');
      }

      // Emit event through stream
      try {
        _notificationStream.add(notification);
        print('✅ Emitted notification through stream');
      } catch (e) {
        print('❌ Error emitting notification stream: $e');
      }

      print('✅ Notification processed: ${notification['title']} - Type: ${notification['type']}');
      print('═══════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════');
      print('❌ CRITICAL ERROR processing notification:');
      print('   Error: $e');
      print('   Stack trace:');
      print(stackTrace);
      print('   Original data: $data');
      print('═══════════════════════════════════════════════════');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final rawType = data['type']?.toString().toLowerCase() ?? '';
      final hasPromoId = data['promotion_id'] != null;
      final type = (rawType.isEmpty && hasPromoId) ? 'promotion' : rawType;
      
      final orderId = data['order_id'];
      final restaurantId = data['restaurant_id'];
      final promotionId = data['promotion_id'];

      // Mark notification as read
      _markNotificationAsRead(data);

      // Navigate based on notification type
      if (type.contains('promotion') || type == 'new_promotion') {
        if (promotionId != null) {
          Get.toNamed('/promotion-details/$promotionId');
        } else if (restaurantId != null) {
          Get.toNamed('/restaurant/$restaurantId?tab=promotions');
        } else {
          Get.toNamed('/promotions');
        }
        return;
      }

      switch (type) {
        case 'order_update':
          if (orderId != null) {
            Get.toNamed('/order-details/$orderId');
          } else {
            Get.toNamed('/orders');
          }
          break;


        case 'restaurant':
          if (restaurantId != null) {
            Get.toNamed('/restaurant/$restaurantId');
          }
          break;

        default:
          Get.toNamed('/notifications');
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final Map<String, dynamic> data = json.decode(response.payload!);
        _handleNotificationTap(data);
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  // void _handleNotificationTap(Map<String, dynamic> data) {
  //   try {
  //     final type = data['type'] ?? 'order';
  //     final orderId = data['order_id'];
  //     final restaurantId = data['restaurant_id'];

  //     // Mark notification as read
  //     _markNotificationAsRead(data);

  //     // Navigate based on notification type
  //     switch (type) {
  //       case 'order_update':
  //         if (orderId != null) {
  //           Get.toNamed('/order-details/$orderId');
  //         } else {
  //           Get.toNamed('/orders');
  //         }
  //         break;

  //       case 'order_placed':
  //         Get.toNamed('/orders');
  //         break;

  //       case 'order_accepted':
  //         if (orderId != null) {
  //           Get.toNamed('/order-tracking/$orderId');
  //         }
  //         break;

  //       case 'order_out_for_delivery':
  //         if (orderId != null) {
  //           Get.toNamed('/order-tracking/$orderId');
  //         }
  //         break;

  //       case 'order_delivered':
  //         if (orderId != null) {
  //           Get.toNamed('/order-details/$orderId');
  //         }
  //         break;

  //       case 'promotion':
  //         Get.toNamed('/promotions');
  //         break;

  //       case 'restaurant':
  //         if (restaurantId != null) {
  //           Get.toNamed('/restaurant/$restaurantId');
  //         }
  //         break;

  //       default:
  //         Get.toNamed('/notifications');
  //     }
  //   } catch (e) {
  //     print('❌ Error handling notification tap: $e');
  //   }
  // }

  void _updateOrderController(Map<String, dynamic> data) {
    try {
      if (_orderController == null) {
        _orderController = Get.find<OrderController>();
      }

      final orderId = data['order_id'];
      if (orderId != null) {
        // Refresh order details in background
        _orderController?.getOrderDetail(int.tryParse(orderId.toString()) ?? 0);

        // Clear notification count if order is delivered
        if (data['status'] == 'delivered' || data['status'] == 'completed') {
          _orderController?.clearOrderNotification(orderId);
        }
      }
    } catch (e) {
      print('❌ Error updating order controller: $e');
    }
  }

  void _updatePromotionController(Map<String, dynamic> data) {
    try {
      print('═══════════════════════════════════════════════════');
      print('🎁 UPDATING PROMOTION CONTROLLER');
      
      // Log the promotion notification details
      final promotionId = data['promotion_id'];
      final action = data['action'] ?? data['type'] ?? 'unknown';
      final isActive = data['is_active'];
      
      print('📣 Promotion notification received:');
      print('   - Promotion ID: $promotionId');
      print('   - Action: $action');
      print('   - Is Active: $isActive');
      print('   - Title: ${data['title'] ?? data['name']}');
      print('   - Body: ${data['body'] ?? data['description']}');
      print('   - Full data: $data');
      
      // CRITICAL FIX: Check if PromotionController is registered before trying to use it
      if (!Get.isRegistered<PromotionController>()) {
        print('⚠️  PromotionController NOT registered yet!');
        print('   This is normal if user hasn\'t navigated to promotions page yet.');
        print('   Promotion list will be updated when user navigates to promotions page');
        print('═══════════════════════════════════════════════════');
        // Controller will load promotions when it initializes
        return;
      }
      
      print('✅ PromotionController is registered');
      
      try {
        final promotionController = Get.find<PromotionController>();
        print('✅ Found PromotionController instance');
        print('🔄 Refreshing promotions to reflect activation/deactivation changes...');
        
        // Refresh promotions in background - fetches updated list with new is_active states
        promotionController.refreshPromotions();
        
        print('✅ Promotion refresh triggered successfully');
        print('   Controller will fetch updated promotion list from backend');
      } catch (e, stackTrace) {
        print('❌ ERROR calling refreshPromotions:');
        print('   Error: $e');
        print('   Stack trace:');
        print(stackTrace);
      }
      
      print('═══════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════');
      print('❌ CRITICAL ERROR in _updatePromotionController:');
      print('   Error: $e');
      print('   Stack trace:');
      print(stackTrace);
      print('   Data received: $data');
      print('═══════════════════════════════════════════════════');
      // Don't crash the app if promotion refresh fails
    }
  }
  Future<void> _loadSavedNotifications() async {
    try {
      final saved = _storage.read<List>('notifications');
      if (saved != null) {
        _notifications.assignAll(
          saved.map((item) => Map<String, dynamic>.from(item)).toList(),
        );
        print('✅ Loaded ${_notifications.length} saved notifications');
      }
    } catch (e) {
      print('❌ Error loading saved notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      await _storage.write('notifications', _notifications.toList());
    } catch (e) {
      print('❌ Error saving notifications: $e');
    }
  }

  void _markNotificationAsRead(Map<String, dynamic> data) {
    try {
      final notificationId = data['notification_id'] ?? data['order_id'];
      if (notificationId != null) {
        for (int i = 0; i < _notifications.length; i++) {
          final notif = _notifications[i];
          if ((notif['data']['notification_id'] == notificationId ||
                  notif['data']['order_id'] == notificationId) &&
              notif['read'] == false) {
            _notifications[i]['read'] = true;
            break;
          }
        }
        _saveNotifications();
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Public methods
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i]['read'] = true;
    }
    _hasNewNotification.value = false;
    await _saveNotifications();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    _hasNewNotification.value = false;
    await _storage.remove('notifications');
  }

  Future<void> removeNotification(int index) async {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      await _saveNotifications();
    }
  }

  void refreshOrdersIfNeeded() {
    try {
      if (_orderController == null) {
        _orderController = Get.find<OrderController>();
      }
      _orderController?.refreshOrders();
    } catch (e) {
      print('❌ Error refreshing orders: $e');
    }
  }

  // Send test notification (for development)
  Future<void> sendTestNotification() async {
    try {
      await _apiService.post('users/auth/notification/test/', {
        'title': 'Test Notification',
        'message': 'This is a test notification from the app',
        'data': {
          'type': 'test',
          'test_id': DateTime.now().millisecondsSinceEpoch,
        },
      });
      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // Unregister device when user logs out
  Future<void> unregisterDevice() async {
    try {
      final token = _storage.read('fcm_token');
      if (token != null) {
        await _apiService.delete(
          'users/auth/device/unregister/',
          data: {'registration_id': token},
        );
        print('✅ Device unregistered from notifications');
      }
    } catch (e) {
      print('❌ Error unregistering device: $e');
    }
  }

  // Check if user has notification permission
  Future<bool> hasPermission() async {
    final NotificationSettings settings = await _firebaseMessaging
        .getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Subscribe to topics
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }
}
