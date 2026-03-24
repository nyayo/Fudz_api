import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:get/get.dart';

class PhoneAuthController extends GetxController {
  final ApiService _apiService = Get.find();

  final TextEditingController phoneController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  final RxBool isLoading = false.obs;
  final RxBool isResending = false.obs;
  final RxString error = ''.obs;

  /// The full phone number in international format, e.g. +256712345678
  String get fullPhone => '+256${phoneController.text.trim()}';

  // ── helpers ──────────────────────────────────────────────────────────

  String _sanitizeError(Object e, [StackTrace? st]) {
    try {
      debugPrint('PhoneAuthController error: $e');
      if (st != null) debugPrint(st.toString());
    } catch (_) {}

    String message = 'An unexpected error occurred';
    String? debugInfo;

    if (e is SocketException) {
      message = 'Network error. Please check your connection.';
      debugInfo = 'SocketException: Unable to reach server';
    } else if (e is TimeoutException) {
      message = 'Network timeout. Please try again.';
      debugInfo = 'Timeout: Server took too long to respond';
    } else {
      final s = e.toString().toLowerCase();
      
      if (s.contains('phone number must be in international format') || 
          s.contains('invalid phone number')) {
        message = 'Please enter a valid phone number (9 digits after +256)';
        debugInfo = 'Phone number format error';
      } else if (s.contains('invalid otp') || s.contains('otp expired')) {
        message = 'Invalid or expired code. Please try again.';
        debugInfo = 'OTP validation failed';
      } else if (s.contains('quota exceeded') || s.contains('too many requests')) {
        message = 'Too many requests. Please wait a few minutes and try again.';
        debugInfo = 'Rate limit: Too many OTP requests';
      } else if (s.contains('firebase')) {
        message = 'SMS service error. Please try again later.';
        debugInfo = 'Firebase Auth error: ${e.toString()}';
      } else if (s.contains('failed host lookup') ||
          s.contains('network') ||
          s.contains('socketexception')) {
        message = 'Network error. Please check your connection.';
        debugInfo = 'Network connectivity issue';
      } else if (s.contains('timed out')) {
        message = 'Network timeout. Please try again.';
        debugInfo = 'Request timed out';
      } else if (s.contains('user disabled')) {
        message = 'This account has been disabled.';
        debugInfo = 'User account disabled in Firebase';
      } else if (s.contains('invalid phone')) {
        message = 'The phone number is invalid.';
        debugInfo = 'Invalid phone number format';
      } else if (s.contains('session expired')) {
        message = 'Session expired. Please request a new code.';
        debugInfo = 'Firebase session expired';
      } else if (s.contains('400') || s.contains('bad request')) {
        message = 'Invalid request. Please check your phone number.';
        debugInfo = 'Bad request (400) - check phone format';
      } else if (s.contains('401') || s.contains('unauthorized')) {
        message = 'Authentication failed. Please try again.';
        debugInfo = 'Unauthorized (401)';
      } else if (s.contains('500') || s.contains('internal server error')) {
        message = 'Server error. Please try again later.';
        debugInfo = 'Server error (500)';
      } else {
        message = 'Please try again.';
        debugInfo = 'Unknown error: ${e.toString()}';
      }
    }
    
    if (message.length > 120) message = '${message.substring(0, 120)}...';
    
    debugPrint('DEBUG INFO: $debugInfo');
      
    return message;
  }

  @override
  void onClose() {
    phoneController.dispose();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var n in focusNodes) {
      n.dispose();
    }
    super.onClose();
  }

  // ── request OTP ──────────────────────────────────────────────────────

  Future<void> requestOtp() async {
    try {
      isLoading.value = true;
      error.value = '';

      final phone = phoneController.text.trim();
      
      debugPrint('=== OTP Request Debug ===');
      debugPrint('Raw phone input: "$phone"');
      debugPrint('Full phone (with +256): $fullPhone');
      debugPrint('Phone length: ${phone.length}');
      debugPrint('==========================');
      
      if (phone.isEmpty) {
        throw Exception('Please enter a phone number');
      }
      
      if (phone.length < 9) {
        throw Exception('Phone number must be at least 9 digits (e.g., 712345678)');
      }
      
      if (phone.length > 10) {
        throw Exception('Phone number should be at most 10 digits');
      }

      if (phone.startsWith('0')) {
        throw Exception('Please enter phone without leading 0 (e.g., 712345678, not 0712345678)');
      }

      final response = await _apiService.postPublic(
        'users/auth/phone/request-otp/',
        {'phone': fullPhone},
      );

      debugPrint('OTP Request Response: $response');

      if (response != null && response['success'] == true) {
        Get.toNamed('/phone_verification', arguments: fullPhone);
        Get.snackbar(
          'Success',
          'Verification code sent to $fullPhone',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else if (response != null && response['error'] != null) {
        final serverError = response['error'].toString();
        debugPrint('Server error response: $serverError');
        throw Exception(serverError);
      } else if (response != null) {
        Get.toNamed('/phone_verification', arguments: fullPhone);
        Get.snackbar(
          'Success',
          'Verification code sent to $fullPhone',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Failed to send verification code - no response from server');
      }
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      debugPrint('Full error details: $e');
      debugPrint('Stack trace: $st');
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── verify OTP ───────────────────────────────────────────────────────

  Future<void> verifyOtp(String phone) async {
    try {
      isLoading.value = true;
      error.value = '';

      if (!isOtpComplete()) {
        throw Exception('Please enter the complete 6-digit verification code');
      }

      final otp = otpControllers.map((c) => c.text).join();
      debugPrint('=== OTP Verification Debug ===');
      debugPrint('Verifying phone OTP for: $phone');
      debugPrint('OTP entered: ${otp.substring(0, 2)}***${otp.substring(4)}');
      debugPrint('================================');

      final response = await _apiService.postPublic(
        'users/auth/phone/verify-otp/',
        {'phone': phone, 'otp': otp},
      );

      debugPrint('Phone OTP Response: $response');

      if (response == null) {
        throw Exception('No response from server. Please check your network.');
      }

      if (response['error'] != null) {
        throw Exception(response['error'].toString());
      }

      if (response['success'] == false) {
        final errorMsg = response['message'] ?? response['error'] ?? 'Verification failed';
        throw Exception(errorMsg);
      }

      if (response.isNotEmpty && (response['user_exists'] == true || response['requires_registration'] == true)) {
        final userController = Get.find<UserController>();
        final tokenService = Get.find<TokenService>();

        if (response['user_exists'] == true) {
          if (response['tokens'] != null) {
            await tokenService.saveTokens(response['tokens']);
            if (response['user'] != null) {
              await userController.createUserFromOtpResponse(response['user']);
            }
            // Check if user can link Google and update state
            final canLinkGoogle = response['can_link_google'] == true;
            userController.isGoogleLinked.value = !canLinkGoogle;
            Get.offAllNamed('/home');
            // Show Google link prompt if available
            if (canLinkGoogle) {
              userController.showGoogleLinkPrompt();
            }
          } else {
            throw Exception('Authentication tokens not received');
          }
        } else if (response['requires_registration'] == true) {
          Get.offAllNamed(
            '/register',
            arguments: {'phone': phone, 'from_phone': true},
          );
        } else {
          throw Exception('Unexpected response from server');
        }
      } else {
        throw Exception('Verification failed. Please check the code and try again.');
      }
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      debugPrint('Verify OTP Error: $e');
      debugPrint('Stack trace: $st');
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ── resend ───────────────────────────────────────────────────────────

  Future<void> resendOtp(String phone) async {
    try {
      isResending.value = true;
      error.value = '';

      debugPrint('=== Resend OTP Debug ===');
      debugPrint('Phone: $phone');
      debugPrint('========================');

      final response = await _apiService.postPublic(
        'users/auth/phone/request-otp/',
        {'phone': phone},
      );

      debugPrint('Resend OTP Response: $response');

      if (response == null) {
        throw Exception('No response from server. Please check your network.');
      }

      if (response['error'] != null) {
        throw Exception(response['error'].toString());
      }

      if (response['success'] == false) {
        final errorMsg = response['message'] ?? response['error'] ?? 'Failed to resend code';
        throw Exception(errorMsg);
      }

      for (var c in otpControllers) {
        c.clear();
      }
      if (focusNodes.isNotEmpty) focusNodes[0].requestFocus();
      Get.snackbar(
        'Success',
        'New verification code sent',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e, st) {
      final msg = _sanitizeError(e, st);
      error.value = msg;
      debugPrint('Resend OTP Error: $e');
      Get.snackbar(
        'Error',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isResending.value = false;
    }
  }

  // ── utils ────────────────────────────────────────────────────────────

  bool isOtpComplete() => otpControllers.every((c) => c.text.isNotEmpty);

  String getOtp() => otpControllers.map((c) => c.text).join();

  void clearOtpFields() {
    for (var c in otpControllers) {
      c.clear();
    }
  }
}
