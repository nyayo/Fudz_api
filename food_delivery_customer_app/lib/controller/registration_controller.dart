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
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Email will be passed from OTP verification
  String? email;

  @override
  void onInit() {
    super.onInit();
    // Get email from arguments when controller is created
    final arguments = Get.arguments;
    if (arguments != null && arguments['email'] != null) {
      email = arguments['email'];
      print('📧 Registration email: $email');
    }
  }

  Future<void> registerUser() async {
    try {
      isLoading.value = true;
      error.value = '';

      // Validate that we have the email from OTP
      if (email == null || email!.isEmpty) {
        throw Exception(
          'Email is required. Please start from OTP verification.',
        );
      }

      // Validate required fields
      if (firstNameController.text.isEmpty || lastNameController.text.isEmpty) {
        throw Exception('Please enter your name');
      }

      if (phoneController.text.isEmpty) {
        throw Exception('Please enter your phone number');
      }

      if (passwordController.text.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }

      if (passwordController.text != confirmPasswordController.text) {
        throw Exception('Passwords do not match');
      }

      // Prepare registration data - force user_type to 'customer'
      final registrationData = {
        'email': email!,
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'user_type': 'customer', // Force customer type
        'password': passwordController.text,
        'password2': confirmPasswordController.text,
      };

      print('📝 Registration data: $registrationData');

      final response = await _apiService.postPublic(
        'users/auth/register/',
        registrationData,
      );

      print('✅ Registration response: $response');

      // Save tokens and login user
      if (response['tokens'] != null) {
        await _tokenService.saveTokens(response['tokens']);
        // Create user object
        final userController = Get.find<UserController>();
        await userController.refreshAuthStateFromStorage();
        if (response['user'] != null) {
          await userController.createUserFromOtpResponse(response['user']);
        }

        Get.offAllNamed('/home');

        Get.snackbar(
          'Success',
          'Registration completed successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
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
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
