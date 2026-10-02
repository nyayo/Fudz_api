import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';

import 'package:get/get.dart';

class RegistrationController extends GetxController {
  final ApiService _apiService = Get.find();
  final TokenService _tokenService = TokenService();

  // Force user type to customer for new registrations
  final RxString selectedUserType = 'customer'.obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  // Form controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Email verification for phone-first flow
  final List<TextEditingController> otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());
  final RxBool isEmailVerified = false.obs;
  final RxBool isVerifyingEmail = false.obs;
  final RxBool isSendingOtp = false.obs;
  final RxBool showOtpFields = false.obs;

  /// True when the user arrived from phone OTP verification
  bool fromPhone = false;

  // Email will be passed from OTP verification (email-first flow)
  String? email;
  // Phone from phone-first flow
  String? phone;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments != null) {
      if (arguments['email'] != null) {
        email = arguments['email'];
        emailController.text = email!;
        isEmailVerified.value = true; // already verified via email OTP flow
        print('📧 Registration email: $email');
      }
      if (arguments['phone'] != null) {
        phone = arguments['phone'];
        phoneController.text = phone!;
        print('📱 Registration phone: $phone');
      }
      if (arguments['from_phone'] == true) {
        fromPhone = true;
      }
    }
  }

  // ── Email verification (phone-first flow) ──

  Future<void> requestEmailOtp() async {
    try {
      isSendingOtp.value = true;
      error.value = '';
      final emailText = emailController.text.trim();
      if (emailText.isEmpty || !emailText.contains('@')) {
        throw Exception('Please enter a valid email address');
      }

      final response = await _apiService.postPublic(
        'users/auth/request-otp/',
        {'email': emailText},
      );

      if (response != null) {
        showOtpFields.value = true;
        Get.snackbar(
          'Success',
          'Verification code sent to $emailText',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Failed to send verification code');
      }
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSendingOtp.value = false;
    }
  }

  Future<void> verifyEmailOtp() async {
    try {
      isVerifyingEmail.value = true;
      error.value = '';

      final otp = otpControllers.map((c) => c.text).join();
      if (otp.length < 6) {
        throw Exception('Please enter the complete verification code');
      }

      final emailText = emailController.text.trim();
      final response = await _apiService.postPublic(
        'users/auth/verify-otp/',
        {'email': emailText, 'otp': otp},
      );

      if (response != null && response['verified'] == true) {
        isEmailVerified.value = true;
        email = emailText;
        showOtpFields.value = false;
        Get.snackbar(
          'Verified',
          'Email verified successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Email verification failed');
      }
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isVerifyingEmail.value = false;
    }
  }

  bool get isOtpComplete =>
      otpControllers.every((c) => c.text.isNotEmpty);

  // ── Registration ──

  Future<void> registerUser() async {
    try {
      isLoading.value = true;
      error.value = '';

      // For phone-first flow, email must be verified inline
      final effectiveEmail = email ?? emailController.text.trim();

      if (effectiveEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      if (!isEmailVerified.value) {
        throw Exception(
          'Please verify your email address before registering.',
        );
      }

      if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
        throw Exception('Please enter your name');
      }

      final effectivePhone = phone ?? phoneController.text.trim();
      if (effectivePhone.isEmpty) {
        throw Exception('Please enter your phone number');
      }

      if (passwordController.text.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      if (passwordController.text != confirmPasswordController.text) {
        throw Exception('Passwords do not match');
      }

      final registrationData = {
        'email': effectiveEmail,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'phone': effectivePhone,
        'user_type': 'customer',
        'password': passwordController.text,
        'password2': confirmPasswordController.text,
      };

      print('📝 Registration data: $registrationData');

      final response = await _apiService.postPublic(
        'users/auth/register/',
        registrationData,
      );

      print('✅ Registration response: $response');

      if (response['tokens'] != null) {
        await _tokenService.saveTokens(response['tokens']);
        final userController = Get.find<UserController>();
        await userController.refreshAuthStateFromStorage();
        if (response['user'] != null) {
          await userController.createUserFromOtpResponse(response['user']);
        }

        // New registration — can_link_google is always true
        final canLinkGoogle = response['can_link_google'] == true;
        userController.isGoogleLinked.value = false;

        Get.offAllNamed('/home');

        Get.snackbar(
          'Success',
          'Registration completed successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Prompt to link Google after registration
        if (canLinkGoogle) {
          userController.showGoogleLinkPrompt();
        }
      } else {
        throw Exception('Registration failed - no tokens received');
      }
    } catch (e) {
      error.value = e.toString();
      print('❌ Registration error: $e');
      Get.snackbar(
        'Registration Failed',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var n in otpFocusNodes) {
      n.dispose();
    }
    super.onClose();
  }
}
