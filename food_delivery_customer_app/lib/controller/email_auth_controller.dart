import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';

import 'package:get/get.dart';

import 'package:http/http.dart' as http;

class EmailAuthController extends GetxController {
  final ApiService _apiService = Get.find();

  final TextEditingController emailController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

  final RxBool isLoading = false.obs;
  final RxBool isResending = false.obs;
  final RxString error = ''.obs;

  String _sanitizeError(Object e, [StackTrace? st]) {
    try {
      debugPrint('EmailAuthController error: $e');
      if (st != null) debugPrint(st.toString());
    } catch (_) {}

    String message = 'An unexpected error occurred';

    if (e is SocketException) {
      message = 'Network error. Please check your connection.';
    } else if (e is TimeoutException) {
      message = 'Network timeout. Please try again.';
    } else {
      final s = e.toString().toLowerCase();

      if (s.contains('please enter a valid email') ||
          s.contains('please enter the complete verification code')) {
        message = _stripToSingleLine(e.toString());
      } else if (s.contains('401') ||
          s.contains('403') ||
          s.contains('session expired')) {
        message = 'Session expired. Please login again.';
      } else if (s.contains('failed host lookup') ||
          s.contains('network') ||
          s.contains('socketexception')) {
        message = 'Network error. Please check your connection.';
      } else if (s.contains('timed out')) {
        message = 'Network timeout. Please try again.';
      } else if (s.contains('invalid') && s.contains('credentials')) {
        message = 'Invalid credentials.';
      } else {
        message = 'Please try again.';
      }
    }

    message = _stripToSingleLine(message);
    if (message.length > 120) message = message.substring(0, 120) + '...';
    return message;
  }

  String _stripToSingleLine(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  void onClose() {
    emailController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.onClose();
  }

  Future<void> requestOtp() async {
    try {
      isLoading.value = true;
      error.value = '';

      final email = emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }

      // Use public API call (no authentication headers)
      final response = await _apiService.postPublic('users/auth/request-otp/', {
        'email': email,
      });

      if (response != null) {
        Get.toNamed('/email_verification', arguments: email);

        Get.snackbar(
          'Success',
          'Verification code sent to your email',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Failed to send verification code');
      }
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // In email_auth_controller.dart, update verifyOtp method
  Future<void> verifyOtp(String email) async {
    try {
      isLoading.value = true;
      error.value = '';

      if (!isOtpComplete()) {
        throw Exception('Please enter the complete verification code');
      }

      final otp = otpControllers.map((controller) => controller.text).join();

      print('Verifying OTP for email: $email');

      // Use public API call for OTP verification
      final response = await _apiService.postPublic('users/auth/verify-otp/', {
        'email': email,
        'otp': otp,
      });

      print('OTP Verification Response: $response');

      if (response != null && response.isNotEmpty) {
        final userController = Get.find<UserController>();
        final tokenService = Get.find<TokenService>();

        // Check if user exists and get tokens
        if (response['user_exists'] == true) {
          // User exists - save tokens and login
          if (response['tokens'] != null) {
            await tokenService.saveTokens(response['tokens']);
            print('Tokens saved successfully');

            // Create user from OTP response instead of fetching profile
            if (response['user'] != null) {
              await userController.createUserFromOtpResponse(response['user']);
              print('✅ User created from OTP response');
            }

            print('User logged in successfully, navigating to home');
            Get.offAllNamed('/home');
          } else {
            throw Exception('Authentication tokens not received');
          }
        } else if (response['requires_registration'] == true) {
          // New user - navigate to registration with email pre-filled
          print('New user detected, navigating to registration');
          Get.offAllNamed(
            '/register',
            arguments: {
              'email': email,
              'userType': 'customer', // Force customer type for new users
            },
          );
        } else {
          throw Exception('Unexpected response from server');
        }
      } else {
        throw Exception('Failed to verify OTP - empty response');
      }
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      print('OTP Verification Error: $e');
      print('Stack trace: $st');

      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Add this helper method for public API calls
  Future<dynamic> _makePublicApiCall(String endpoint, dynamic data) async {
    try {
      print('Making public API call to: $endpoint');

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 30));

      return await _handlePublicResponse(response);
    } catch (e) {
      print('Public API call error: $e');
      rethrow;
    }
  }

  Future<dynamic> _handlePublicResponse(http.Response response) async {
    print(
      'Public API Response - Status: ${response.statusCode}, URL: ${response.request?.url}',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};

      try {
        return json.decode(response.body);
      } catch (e) {
        print('JSON Parse Error: $e');
        throw Exception('Failed to parse response: $e');
      }
    } else {
      print(
        'Public API Error - Status: ${response.statusCode}, Body: ${response.body}',
      );
      try {
        final error = json.decode(response.body);
        throw Exception(
          error['detail'] ??
              error['message'] ??
              error['error'] ??
              'Something went wrong',
        );
      } catch (e) {
        throw Exception(
          'Something went wrong (Status: ${response.statusCode})',
        );
      }
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      isResending.value = true;

      final response = await _apiService.post('auth/request-otp/', {
        'email': email,
      });

      // Add null safety check
      if (response != null) {
        // Clear existing OTP
        for (var controller in otpControllers) {
          controller.clear();
        }
        if (focusNodes.isNotEmpty) {
          focusNodes[0].requestFocus();
        }

        Get.snackbar(
          'Success',
          'New verification code sent',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Failed to resend OTP');
      }
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isResending.value = false;
    }
  }

  bool isOtpComplete() {
    return otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  String getOtp() {
    return otpControllers.map((controller) => controller.text).join();
  }
}
