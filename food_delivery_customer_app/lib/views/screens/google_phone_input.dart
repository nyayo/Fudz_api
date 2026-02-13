// views/auth/google_phone_input.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/views/widgets/round_button.dart';

import 'package:get/get.dart';

class GooglePhoneInputScreen extends StatefulWidget {
  final Map<String, dynamic> googleUserData;

  const GooglePhoneInputScreen({super.key, required this.googleUserData});

  @override
  State<GooglePhoneInputScreen> createState() => _GooglePhoneInputScreenState();
}

class _GooglePhoneInputScreenState extends State<GooglePhoneInputScreen> {
  final TextEditingController phoneController = TextEditingController();
  final UserController userController = Get.find<UserController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.back();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: media.height * 0.05),

                // Header
                Center(
                  child: Icon(
                    Icons.phone_iphone,
                    size: 80,
                    color: TColor.primary,
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    "Phone Number Required",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: TColor.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    "We need your phone number to complete\nyour registration",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ),

                const SizedBox(height: 40),

                // User info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Account Details:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: TColor.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Name: ${widget.googleUserData['first_name']} ${widget.googleUserData['last_name']}",
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        "Email: ${widget.googleUserData['email']}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Phone input
                Text(
                  "Phone Number *",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          "+256",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Colors.grey),
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.length < 9) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 12,
                            ),
                            hintText: "Enter phone number",
                            border: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "We'll send you order updates and important notifications",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),

                const SizedBox(height: 40),

                // Continue button
                Obx(
                  () => RoundButton(
                    title: "Complete Registration",
                    onPressed: userController.isLoading.value
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              await _completeRegistration();
                            }
                          },
                    bgcolor: TColor.primary,
                    color1: Colors.white,
                    isLoading: userController.isLoading.value,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeRegistration() async {
    try {
      // Combine Google data with phone number
      final completeUserData = {
        ...widget.googleUserData,
        'phone': '+256${phoneController.text.trim()}',
      };

      // Send to backend for registration
      await userController.registerUserWithGoogle(completeUserData);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to complete registration: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }
}
