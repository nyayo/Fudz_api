import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_customer_app/controller/cart_controller.dart';
import 'package:food_delivery_customer_app/controller/order_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/controller/wishlist_controller.dart';
import 'package:food_delivery_customer_app/models/user.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/error_logger_service.dart';
import 'package:food_delivery_customer_app/services/google.dart';
import 'package:food_delivery_customer_app/services/notification_service.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:get/get.dart';

import 'package:get_storage/get_storage.dart';

class UserController extends GetxController {
  final ApiService _apiService = Get.find();
  final TokenService _tokenService = Get.find<TokenService>();
  final GoogleSignInService _googleSignInService =
      Get.find<GoogleSignInService>();
  ErrorLoggerService? _errorLogger;

  // Reactive user object
  final Rx<User?> _user = Rx<User?>(null);
  Rx<User?> get userObs => _user;

  final RxBool isLoading = false.obs;
  final RxBool isRefreshingToken = false.obs;
  final RxString error = ''.obs;

  // Guard against duplicate service initialization
  bool _servicesInitialized = false;

  // Reactive access token
  final RxString _accessToken = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Get error logger if available
    if (Get.isRegistered<ErrorLoggerService>()) {
      _errorLogger = Get.find<ErrorLoggerService>();
    }
    // Only sync token from storage on init.
    // checkAuthStatus() is called by SplashScreen to avoid duplicate work.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await syncTokenFromStorage();
    });
  }

  // Getters
  User? get user => _user.value;
  bool get isLoggedIn {
    // Check both reactive variable AND storage directly
    if (_accessToken.value.isNotEmpty) {
      return true;
    }

    // Fallback to check storage synchronously
    final tokenFromStorage = GetStorage().read(TokenService.accessTokenKey);
    if (tokenFromStorage != null &&
        tokenFromStorage is String &&
        tokenFromStorage.isNotEmpty) {
      // Update the reactive variable
      _accessToken.value = tokenFromStorage;
      return true;
    }

    return false;
  }

  String? get accessToken {
    // If we have token in reactive variable, use it
    if (_accessToken.value.isNotEmpty) {
      return _accessToken.value;
    }

    // Otherwise check storage
    final tokenFromStorage = GetStorage().read(TokenService.accessTokenKey);
    if (tokenFromStorage != null && tokenFromStorage is String) {
      // Update reactive variable for next time
      _accessToken.value = tokenFromStorage;
      return tokenFromStorage;
    }

    return null;
  }

  Future<void> syncTokenFromStorage() async {
    try {
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';
      print(
        '🔄 Token synced from storage: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
      );
    } catch (e) {
      print('❌ Error syncing token from storage: $e');
      _accessToken.value = '';
    }
  }

  Future<void> _initializeToken() async {
    try {
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';
      print(
        '🔐 Token initialized: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
      );

      // CRITICAL FIX: If we have token, also get user data
      if (_accessToken.value.isNotEmpty) {
        final cachedUser = _tokenService.getUserData();
        if (cachedUser != null) {
          _user.value = cachedUser;
        }
      }
    } catch (e) {
      print('❌ Error initializing token: $e');
      _accessToken.value = '';
    }
  }

  // Update token when it changes
  Future<void> _updateToken(String? token) async {
    _accessToken.value = token ?? '';
    print(
      '🔐 Token updated: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      error.value = '';

      print('🔐 Starting Google authentication process...');

      // Get Google user account
      final GoogleSignInAccount? googleUser = await _googleSignInService
          .signIn();
      if (googleUser == null) {
        _errorLogger?.logAuthWarning('Google Sign-in cancelled by user');
        _showSafeSnackbar('Sign-In Cancelled', 'Google Sign-In was cancelled');
        return;
      }

      print('✅ Google authentication successful, getting auth tokens...');

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Extract user data
      final nameParts = (googleUser.displayName ?? '').split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // CRITICAL FIX: Backend validates access_token, NOT id_token
      if (googleAuth.accessToken == null) {
        final errorMsg = 'Failed to get Google access token';
        _errorLogger?.logGoogleApiError(
          message: errorMsg,
          details: 'Google authentication returned null access token',
        );
        throw Exception(errorMsg);
      }

      // Prepare auth data for backend EXACTLY as backend expects
      // Backend GoogleSignInSerializer requires: access_token, id_token, user_type
      final authDataForBackend = {
        'access_token': googleAuth.accessToken!, // REQUIRED
        'id_token': googleAuth.idToken, // REQUIRED by backend
        'user_type': 'customer', // REQUIRED
        // Don't send other fields yet - backend will tell us if registration is needed
      };

      print('📤 Sending to backend: ${authDataForBackend.keys}');

      _errorLogger?.logAuthInfo(
        'Sending Google auth data to backend',
        metadata: {
          'email': googleUser.email,
          'user_type': 'customer',
          'has_access_token': authDataForBackend.containsKey('access_token'),
        },
      );

      // Call backend Google auth endpoint
      final response = await _apiService.googleAuth(authDataForBackend);

      print('✅ Backend Google authentication response received');

      // Store Google user data for later use if registration is needed
      final googleUserData = {
        'access_token': googleAuth.accessToken!,
        'id_token':
            googleAuth.idToken, // Keep for potential secondary verification
        'user_type': 'customer',
        'email': googleUser.email,
        'first_name': firstName,
        'last_name': lastName,
        'photo_url': googleUser.photoUrl,
      };

      // Handle the response
      await _handleGoogleAuthResponse(response, googleUserData);
    } on TimeoutException catch (e, stackTrace) {
      error.value =
          'Connection timeout. Please check your internet and try again.';
      print('❌ Google Sign-In timeout: $e');
      _errorLogger?.logNetworkError(
        message: 'Google Sign-in timeout',
        error: e,
        stackTrace: stackTrace,
      );
      _showSafeSnackbar('Connection Timeout', error.value);
    } on SocketException catch (e, stackTrace) {
      error.value = 'Network error. Please check your internet connection.';
      print('❌ Google Sign-In network error: $e');
      _errorLogger?.logNetworkError(
        message: 'Google Sign-in network error',
        error: e,
        stackTrace: stackTrace,
      );
      _showSafeSnackbar('Network Error', error.value);
    } catch (e, stackTrace) {
      error.value = _getGoogleSignInError(e);
      print('❌ Google Sign-In error: $e');
      _errorLogger?.logGoogleSignInError(
        message: 'Google Sign-in failed',
        details: error.value,
        error: e,
        stackTrace: stackTrace,
      );
      _showSafeSnackbar('Google Sign-In Failed', error.value);
    } finally {
      isLoading.value = false;
    }
  }

  // Safe snackbar helper methods
  void _showSafeSnackbar(String title, String message) {
    // Use SchedulerBinding instead of WidgetsBinding for better timing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add a small delay to ensure navigation is complete
      Future.delayed(const Duration(milliseconds: 100), () {
        // Check if we're still in a valid context
        if (Get.isRegistered<UserController>() && Get.context != null) {
          try {
            Get.snackbar(
              title,
              message,
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
              margin: const EdgeInsets.all(10),
              borderRadius: 8,
              mainButton: TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/error_log_viewer');
                },
                child: const Text(
                  'View Details',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          } catch (e) {
            debugPrint('Snackbar error: $e - $title: $message');
          }
        } else {
          debugPrint('Context unavailable - $title: $message');
        }
      });
    });
  }

  void _showSnackbarWithNavigatorKey(String title, String message) {
    try {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(10),
        borderRadius: 8,
      );
    } catch (e) {
      debugPrint('Failed to show snackbar even with global key: $e');
    }
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> response) async {
    try {
      print('🔐 Handling authentication response...');

      Map<String, dynamic> tokens = {};

      if (response.containsKey('tokens') && response['tokens'] is Map) {
        tokens = Map<String, dynamic>.from(response['tokens']);
      } else if (response.containsKey('access') ||
          response.containsKey('access_token')) {
        tokens = {
          'access': response['access'] ?? response['access_token'],
          'refresh': response['refresh'] ?? response['refresh_token'],
        };
      } else
        tokens = Map<String, dynamic>.from(response);

      if (tokens['access'] == null) {
        throw Exception('No access token received from server');
      }

      // CRITICAL FIX: Save tokens and update immediately
      await _tokenService.saveTokens(tokens);

      // Force update local token state
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';

      print('✅ Tokens saved successfully');

      if (response.containsKey('user')) {
        final userData = response['user'];
        final user = User.fromJson(userData);
        await _tokenService.saveUserData(user);
        _user.value = user;
        print('✅ User data saved: ${user.email}');
      } else if (response.containsKey('email')) {
        final user = User.fromJson(response);
        await _tokenService.saveUserData(user);
        _user.value = user;
        print('✅ User data created from response: ${user.email}');
      }
    } catch (e) {
      print('❌ Error handling auth response: $e');
      rethrow;
    }
  }

  Future<void> _handleGoogleAuthResponse(
    Map<String, dynamic> response,
    Map<String, dynamic> googleAuthData,
  ) async {
    try {
      print('🔄 Processing Google auth response...');
      print('🔍 Response keys: ${response.keys.toList()}');

      // Check if authentication was successful (has tokens)
      bool hasTokens =
          response.containsKey('access_token') ||
          response.containsKey('access') ||
          response.containsKey('refresh_token') ||
          response.containsKey('refresh') ||
          response.containsKey('tokens');

      // Check if this is a new user needing registration
      bool needsRegistration =
          response.containsKey('requires_registration') &&
          response['requires_registration'] == true;

      // FIXED: Only treat as error if we have error indicators AND no tokens
      // Backend may send 'message' field with success messages like "Login successful."
      bool hasError =
          !hasTokens &&
          (response.containsKey('detail') || response.containsKey('error'));

      print(
        'Analysis - hasTokens: $hasTokens, needsRegistration: $needsRegistration, hasError: $hasError',
      );

      if (hasError) {
        // Handle error response
        final errorMessage =
            response['detail'] ?? response['error'] ?? 'Authentication failed';

        _errorLogger?.logBackendError(
          message: 'Backend returned error during Google auth',
          endpoint: 'users/auth/google/',
          responseBody: errorMessage,
        );

        throw Exception(errorMessage);
      } else if (hasTokens) {
        // SUCCESS: User authenticated successfully (existing or newly registered)
        print('✅ Google authentication successful');

        // Extract and save tokens
        Map<String, dynamic> tokens = {};

        if (response.containsKey('tokens') && response['tokens'] is Map) {
          final tokensMap = Map<String, dynamic>.from(response['tokens']);
          tokens['access'] = tokensMap['access'] ?? tokensMap['access_token'];
          tokens['refresh'] =
              tokensMap['refresh'] ?? tokensMap['refresh_token'];
        } else {
          if (response.containsKey('access_token')) {
            tokens['access'] = response['access_token'];
          } else if (response.containsKey('access')) {
            tokens['access'] = response['access'];
          }

          if (response.containsKey('refresh_token')) {
            tokens['refresh'] = response['refresh_token'];
          } else if (response.containsKey('refresh')) {
            tokens['refresh'] = response['refresh'];
          }
        }

        await _tokenService.saveTokens(tokens);
        await _initializeToken();
        print('✅ Tokens saved successfully');

        // Extract and save user data
        if (response.containsKey('user')) {
          // User data in nested 'user' object
          final userData = response['user'];
          _user.value = User.fromJson(userData);
          await _tokenService.saveUserData(_user.value!);
          print('✅ User data saved from nested object: ${_user.value?.email}');
        } else if (response.containsKey('id') ||
            response.containsKey('email')) {
          // User data in main response object
          _user.value = User.fromJson(response);
          await _tokenService.saveUserData(_user.value!);
          print('✅ User data saved from main object: ${_user.value?.email}');
        } else {
          // Try to get profile from API
          print('⚠️ No user data in response, fetching profile...');
          await getProfile();
        }

        // Initialize services and go to home
        await _initializeUserServices();
        Get.offAllNamed('/home');
      } else if (needsRegistration) {
        // NEW USER: Needs to provide additional information
        print('🆕 New Google user detected, requesting additional info');

        // Prepare data for registration screen
        // Include all fields from googleAuthData plus any additional info from response
        final registrationData = {...googleAuthData, 'user_type': 'customer'};

        // Also include any fields the backend says are required
        if (response.containsKey('required_fields')) {
          print(
            '📋 Required fields from backend: ${response['required_fields']}',
          );
        }

        // Navigate to phone input screen or registration form
        Get.toNamed('/google_phone_input', arguments: registrationData);
      } else {
        // Unexpected response format
        print('❌ Unexpected response format: ${response.keys}');
        _errorLogger?.logBackendError(
          message: 'Unexpected backend response format',
          endpoint: 'users/auth/google/',
          responseBody: response.toString(),
        );
        throw Exception('Unexpected response from server. Please try again.');
      }
    } catch (e) {
      print('❌ Error handling Google auth response: $e');
      rethrow; // Re-throw to be handled by calling method
    }
  }

  Future<void> registerGoogleUser(Map<String, dynamic> registrationData) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('📝 Google Registration data being sent: ${registrationData.keys}');

      // Ensure required fields are present
      final requestBody = {
        'access_token': registrationData['access_token'] ?? '',
        'user_type': 'customer',
        'phone': registrationData['phone'] ?? '',
        'username': registrationData['email']?.split('@').first ?? '',
        'first_name': registrationData['first_name'] ?? '',
        'last_name': registrationData['last_name'] ?? '',
        'email': registrationData['email'] ?? '',
        // Add other fields your backend might need
      };

      // Remove null values
      requestBody.removeWhere((key, value) => value == null || value == '');

      final response = await _apiService.postPublic(
        'users/auth/google/register/',
        requestBody,
      );

      print('✅ Google Registration response: ${response.keys}');

      // Handle response
      if (response.containsKey('access_token') ||
          response.containsKey('access')) {
        await _tokenService.saveTokens(response);
        await _initializeToken();

        // Create user object
        final user = User.fromJson({
          'id': response['id'],
          'email': registrationData['email'],
          'first_name': registrationData['first_name'],
          'last_name': registrationData['last_name'],
          'phone': registrationData['phone'],
          'user_type': 'customer',
          'is_verified': true,
        });

        _user.value = user;
        await _tokenService.saveUserData(user);

        print('✅ Google Registration successful');

        await _initializeUserServices();
        Get.offAllNamed('/home');
      } else if (response.containsKey('detail') ||
          response.containsKey('error')) {
        throw Exception(
          response['detail'] ?? response['error'] ?? 'Registration failed',
        );
      } else {
        throw Exception('Unexpected response format');
      }
    } catch (e) {
      error.value = e.toString();
      print('❌ Google Registration error: $e');

      Get.snackbar(
        'Registration Failed',
        error.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registerUserWithGoogle(Map<String, dynamic> userData) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('📝 Google Registration data: ${userData.keys}');

      // CRITICAL FIX: Send data to google auth endpoint WITH phone number
      // Backend expects: access_token, user_type, and phone for customers
      final registrationData = {
        'access_token': userData['access_token']!,
        'user_type': 'customer',
        'phone': userData['phone']!, // REQUIRED for customers
      };

      print('📝 Sending registration data: ${registrationData.keys}');

      final response = await _apiService.googleAuth(registrationData);

      print('✅ Google Registration response received');

      if (response.containsKey('tokens') || response.containsKey('access')) {
        await _tokenService.saveTokens(
          response.containsKey('tokens') ? response['tokens'] : response,
        );
        await _initializeToken();

        if (response.containsKey('user')) {
          _user.value = User.fromJson(response['user']);
        } else {
          _user.value = User.fromJson({
            'id': response['id'],
            'email': userData['email'],
            'first_name': userData['first_name'],
            'last_name': userData['last_name'],
            'phone': userData['phone'],
            'user_type': 'customer',
            'is_verified': true,
            'username': userData['email'].split('@').first,
          });
        }

        await _tokenService.saveUserData(_user.value!);

        print('✅ Google Registration successful');

        await _initializeUserServices();
        Get.offAllNamed('/home');
      } else if (response.containsKey('id') || response.containsKey('email')) {
        print('✅ Direct user object received');

        await _tokenService.saveTokens({
          'access': response['access_token'] ?? response['access'],
          'refresh': response['refresh_token'] ?? response['refresh'],
        });
        await _initializeToken();

        _user.value = User.fromJson(response);
        await _tokenService.saveUserData(_user.value!);

        await _initializeUserServices();
        Get.offAllNamed('/home');
      } else {
        print('❌ Unexpected registration response format');
        throw Exception(
          'Registration completed but unexpected response format',
        );
      }
    } catch (e) {
      error.value = e.toString();
      print('❌ Google Registration error: $e');

      Get.snackbar(
        'Registration Failed',
        error.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshAuthStateFromStorage() async {
    try {
      print('🔄 Refreshing auth state from storage...');

      // First update token state
      await _initializeToken();

      // Then get cached user
      final cachedUser = _tokenService.getUserData();
      if (cachedUser != null) {
        _user.value = cachedUser;
        print('✅ User loaded from cache: ${_user.value?.email}');
      }

      print('🔄 Auth state refreshed: isLoggedIn=$isLoggedIn');

      // If we're logged in, initialize all user services
      if (isLoggedIn) {
        print('🔄 Initializing user services after auth refresh...');
        await _initializeUserServices();
      }
    } catch (e) {
      print('❌ Error refreshing auth state: $e');
    }
  }

  Future<void> registerUser(Map<String, dynamic> userData) async {
    try {
      isLoading.value = true;
      error.value = '';

      print('📝 Registration data: $userData');
      final response = await _apiService.post('users/auth/register/', userData);

      print('✅ Registration response: $response');

      await _tokenService.saveTokens(response['tokens']);
      await _initializeToken();

      _user.value = User.fromJson(response['user']);
      await _tokenService.saveUserData(_user.value!);

      print('✅ Registration successful');

      await _initializeUserServices();

      Get.offAllNamed('/home');
    } catch (e) {
      error.value = e.toString();
      print('❌ Registration error: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    try {
      isLoading.value = true;
      error.value = '';

      final response = await _apiService.post('auth/verify-otp/', {
        'email': email,
        'otp': otp,
      });

      if (response['user_exists'] == true) {
        // CRITICAL FIX: Save tokens and immediately update local state
        await _tokenService.saveTokens(response['tokens']);

        // CRITICAL FIX: Force initialize token from storage
        final token = await _tokenService.getAccessToken();
        _accessToken.value = token ?? '';

        print(
          '🔐 Token after OTP verification: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
        );

        // Create and save user
        _user.value = User.fromJson(response['user']);
        await _tokenService.saveUserData(_user.value!);

        print('✅ OTP verification successful - User: ${_user.value?.email}');

        // CRITICAL FIX: Initialize services immediately
        await _initializeUserServices();

        Get.offAllNamed('/home');
      } else {
        Get.toNamed('/register', arguments: {'email': email});
      }
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      final response = await _apiService.post('users/auth/login/', {
        'email': email,
        'password': password,
      });

      // CRITICAL FIX: Save tokens FIRST
      await _tokenService.saveTokens(response);

      // CRITICAL FIX: Force initialize token IMMEDIATELY
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';

      print(
        '🔐 Token after login: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
      );

      // Get user profile
      await getProfile();

      print('✅ Login successful - User: ${_user.value?.email}');

      // CRITICAL FIX: Initialize services with the current token
      await _initializeUserServices();

      Get.offAllNamed('/home');
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  String _getGoogleSignInError(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('network_error') ||
        errorString.contains('NetworkError') ||
        errorString.contains('SocketException') ||
        errorString.contains('ApiException: 7')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorString.contains('TimeoutException')) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (errorString.contains('sign_in_failed') ||
        errorString.contains('SIGN_IN_FAILED')) {
      return 'Google Sign-In failed. Please try again.';
    } else if (errorString.contains('cancelled') ||
        errorString.contains('canceled')) {
      return 'Sign-In was cancelled.';
    } else if (errorString.contains('INVALID_ACCOUNT')) {
      return 'Invalid Google account. Please try with a different account.';
    } else if (errorString.contains('invalid') ||
        errorString.contains('Invalid')) {
      return 'Authentication failed. Please try again.';
    } else if (errorString.contains('500') ||
        errorString.contains('internal_error')) {
      return 'Server error. Please try again later.';
    } else if (errorString.contains('400') ||
        errorString.contains('bad_request')) {
      return 'Authentication failed. Please try again.';
    } else {
      return 'Google Sign-In failed. Please try again.';
    }
  }

  Map<String, dynamic> _extractTokens(Map<String, dynamic> response) {
    final tokens = <String, dynamic>{};

    if (response.containsKey('access')) {
      tokens['access'] = response['access'];
    } else if (response.containsKey('access_token')) {
      tokens['access'] = response['access_token'];
    } else if (response.containsKey('token')) {
      tokens['access'] = response['token'];
    }

    if (response.containsKey('refresh')) {
      tokens['refresh'] = response['refresh'];
    } else if (response.containsKey('refresh_token')) {
      tokens['refresh'] = response['refresh_token'];
    }

    if (response.containsKey('expires_in')) {
      tokens['expires_in'] = response['expires_in'];
    } else if (response.containsKey('expiry')) {
      tokens['expiry'] = response['expiry'];
    }

    print(
      '🔑 Extracted tokens - Access: ${tokens['access'] != null ? "present" : "null"}',
    );

    return tokens;
  }

  Future<void> _initializeUserServices() async {
    // Prevent duplicate initialization
    if (_servicesInitialized) {
      print('⏭️ User services already initialized, skipping');
      return;
    }

    try {
      // CRITICAL FIX: First ensure token is synced
      await syncTokenFromStorage();

      if (!isLoggedIn) {
        print('❌ Cannot initialize services: User not logged in');
        return;
      }

      final token = accessToken;
      if (token == null || token.isEmpty) {
        print('❌ Cannot initialize services: No access token after sync');
        return;
      }

      final userId = _user.value?.id.toString() ?? '';
      print('🔄 Initializing all user services...');

      // Run all service initializations in PARALLEL for speed
      final futures = <Future>[];

      // Cart
      final cartController = Get.find<CartController>();
      futures.add(
        cartController.initializeCart(accessToken: token).catchError((e) {
          print('⚠️ Cart init error: $e');
        }),
      );

      // Wishlist
      final wishlistController = Get.find<WishlistController>();
      futures.add(
        wishlistController.loadWishlist(token).catchError((e) {
          print('⚠️ Wishlist init error: $e');
        }),
      );

      // Orders
      final orderController = Get.find<OrderController>();
      futures.add(
        orderController.initializeOrders(accessToken: token).catchError((e) {
          print('⚠️ Orders init error: $e');
        }),
      );

      // Restaurant user login (only if different session)
      if (userId.isNotEmpty) {
        final restaurantController = Get.find<RestaurantController>();
        futures.add(
          restaurantController.onUserLogin(userId).catchError((e) {
            print('⚠️ Restaurant login error: $e');
          }),
        );
      }

      // Wait for all in parallel
      await Future.wait(futures);

      // Notifications setup (non-critical, fire-and-forget)
      _setupNotificationTopics().catchError((e) {
        print('⚠️ Notification setup error: $e');
      });

      _servicesInitialized = true;
      print('✅ All user services initialized successfully');
    } catch (e) {
      print('⚠️ Error initializing user services: $e');
    }
  }

  Future<void> _setupNotificationTopics() async {
    try {
      final notificationService = Get.find<NotificationService>();

      // CRITICAL: Register device token with backend FIRST
      // This enables the backend to send push notifications to this device
      await notificationService.registerDeviceToken();

      // Subscribe to order updates for the current user
      if (_user.value?.id != null) {
        await notificationService.subscribeToTopic('user_${_user.value!.id}');
        await notificationService.subscribeToTopic('customer_notifications');
      }

      print('✅ Notification topics and device token registered successfully');
    } catch (e) {
      print('❌ Error setting up notification topics: $e');
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      // CRITICAL FIX: Force refresh token from storage
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';

      if (isLoggedIn) {
        print('✅ User has token, checking if expired...');

        final isExpired = await _tokenService.isAccessTokenExpired();
        if (isExpired) {
          print('🔄 Token expired, attempting refresh...');
          final refreshed = await refreshAuthToken();
          if (!refreshed) {
            print('❌ Token refresh failed');
          } else {
            print('✅ Token refreshed successfully');
          }
        }

        // Load user data from cache (fast, no network)
        final cachedUser = _tokenService.getUserData();
        if (cachedUser != null) {
          _user.value = cachedUser;
          print('✅ User loaded from cache: ${_user.value?.email}');
        } else {
          // If no cached user but we have token, try to get profile
          try {
            await getProfile();
            print('✅ Profile loaded successfully from API');
          } catch (e) {
            print('⚠️ API profile load failed: $e');
          }
        }

        // NOTE: _initializeUserServices() is NOT called here to avoid
        // duplicate initialization. It is called by SplashScreen and
        // HomePage separately.
      } else {
        print('❌ No valid token found');
      }
    } catch (e) {
      print('❌ Auth status check error: $e');
    }
  }

  Future<bool> refreshAuthToken() async {
    try {
      isRefreshingToken.value = true;
      final success = await _apiService.refreshToken();
      if (success) {
        await _initializeToken();
        print('✅ Token refreshed successfully');
        return true;
      } else {
        print('❌ Token refresh failed');
        return false;
      }
    } catch (e) {
      print('❌ Token refresh error: $e');
      return false;
    } finally {
      isRefreshingToken.value = false;
    }
  }

  Future<void> getProfile({bool fromCache = false}) async {
    try {
      // CRITICAL FIX: Always check token from storage first
      final token = await _tokenService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated - no token in storage');
      }

      if (fromCache) {
        final cachedUser = _tokenService.getUserData();
        if (cachedUser != null) {
          _user.value = cachedUser;
          return;
        }
      }

      final response = await _apiService.get('users/auth/profile/');
      _user.value = User.fromJson(response);
      await _tokenService.saveUserData(_user.value!);

      print('✅ Profile loaded successfully: ${_user.value?.email}');
    } catch (e) {
      print('❌ Get profile error: $e');

      if (e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('Session expired') ||
          e.toString().contains('Not authenticated')) {
        print('🔄 Auth error detected, attempting token refresh...');
        final refreshed = await refreshAuthToken();

        if (refreshed) {
          try {
            final response = await _apiService.get('users/auth/profile/');
            _user.value = User.fromJson(response);
            await _tokenService.saveUserData(_user.value!);
            print(
              '✅ Profile loaded after token refresh: ${_user.value?.email}',
            );
            return;
          } catch (retryError) {
            print('❌ Profile retry failed: $retryError');
          }
        }
      }

      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      // Clear restaurant controller data
      final restaurantController = Get.find<RestaurantController>();
      await restaurantController.onUserLogout();

      // Clear order controller
      final orderController = Get.find<OrderController>();
      orderController.clearOrders();

      // Unregister from notifications
      final notificationService = Get.find<NotificationService>();
      await notificationService.unregisterDevice();

      // Unsubscribe from topics
      if (_user.value?.id != null) {
        await notificationService.unsubscribeFromTopic(
          'user_${_user.value!.id}',
        );
        await notificationService.unsubscribeFromTopic(
          'customer_notifications',
        );
      }

      // Sign out from Google
      await _googleSignInService.signOut();

      // Logout from backend
      if (_accessToken.value.isNotEmpty) {
        final refreshToken = await _tokenService.getRefreshToken();
        if (refreshToken != null) {
          await _apiService
              .post('users/auth/logout/', {'refresh_token': refreshToken})
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  print('⚠️ Logout API timeout - continuing with local logout');
                  return {};
                },
              );
        }
      }
    } catch (e) {
      print('⚠️ Logout API error (non-critical): $e');
    } finally {
      await _tokenService.clearTokens();
      _user.value = null;
      _accessToken.value = '';
      error.value = '';
      isLoading.value = false;

      print('✅ User logged out successfully');
      Get.offAllNamed('/login');
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      isLoading.value = true;
      error.value = '';

      final response = await _apiService.put('users/auth/profile/', updates);
      _user.value = User.fromJson(response);
      await _tokenService.saveUserData(_user.value!);

      print('✅ Profile updated successfully');
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ Update profile error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> checkGoogleAuthStatus() async {
    try {
      return await _googleSignInService.isSignedIn();
    } catch (e) {
      print('❌ Google auth status check error: $e');
      return false;
    }
  }

  Future<void> createUserFromOtpResponse(Map<String, dynamic> userData) async {
    try {
      // CRITICAL FIX: Get token from storage before creating user
      final token = await _tokenService.getAccessToken();
      _accessToken.value = token ?? '';

      _user.value = User.fromJson(userData);
      await _tokenService.saveUserData(_user.value!);

      print('✅ User created from OTP response: ${_user.value?.email}');
      print(
        '🔐 Token state after user creation: ${_accessToken.value.isNotEmpty ? "present" : "empty"}',
      );

      // CRITICAL FIX: Initialize services after user creation
      await _initializeUserServices();
    } catch (e) {
      print('❌ Error creating user from OTP response: $e');
      throw Exception('Failed to create user from OTP response');
    }
  }

  void clearUser() async {
    // Clear restaurant controller data
    final restaurantController = Get.find<RestaurantController>();
    await restaurantController.onUserLogout();

    _user.value = null;
    _accessToken.value = '';
    _tokenService.clearTokens();
    error.value = '';
    _servicesInitialized = false; // Reset service init guard on logout
  }

  Future<bool> needsReauthentication() async {
    if (!isLoggedIn) return true;

    final isExpired = await _tokenService.isAccessTokenExpired();
    return isExpired;
  }

  /// Fast cache-only check for splash screen (non-blocking)
  void checkAuthStatusFromCache() {
    try {
      // Sync token from storage synchronously if needed
      if (_accessToken.value.isEmpty) {
        final tokenFromStorage = GetStorage().read(TokenService.accessTokenKey);
        if (tokenFromStorage != null && tokenFromStorage is String && tokenFromStorage.isNotEmpty) {
          _accessToken.value = tokenFromStorage;
        }
      }

      if (isLoggedIn) {
        // Load user from cache (fast, no network)
        final cachedUser = _tokenService.getUserData();
        if (cachedUser != null) {
          _user.value = cachedUser;
        }
        
        // Background: refresh token if expired and sync profile
        _refreshTokenIfNeeded();
      }
    } catch (e) {
      print('❌ Cache auth check error: $e');
    }
  }

  /// Background token refresh (fire-and-forget)
  Future<void> _refreshTokenIfNeeded() async {
    try {
      final isExpired = await _tokenService.isAccessTokenExpired();
      if (isExpired) {
        refreshAuthToken();
      }
      // Also try to refresh profile in background
      getProfile();
    } catch (e) {
      // Silently fail - user can still use cached data
    }
  }

  Future<String?> getAccessTokenAsync() async {
    return await _tokenService.getAccessToken();
  }

  Future<void> forceTokenCheck() async {
    print('🔄 Force checking token state...');
    await _initializeToken();
    print('🔄 Token check complete - isLoggedIn: $isLoggedIn');
  }

  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('internet')) {
      return 'Please check your internet connection and try again.';
    } else if (errorString.contains('cancelled') ||
        errorString.contains('canceled')) {
      return 'Google Sign-In was cancelled.';
    } else if (errorString.contains('sign_in_failed')) {
      return 'Google Sign-In failed. Please try again.';
    } else if (errorString.contains('invalid') ||
        errorString.contains('token')) {
      return 'Authentication failed. Please try again.';
    } else if (errorString.contains('account_not_found')) {
      return 'No account found with this Google account. Please try signing up first.';
    } else {
      return 'An error occurred during Google Sign-In. Please try again.';
    }
  }
}
