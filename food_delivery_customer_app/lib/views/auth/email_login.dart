import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/email_auth_controller.dart';
import 'package:food_delivery_customer_app/views/widgets/auth_layout_wrapper.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';
import 'package:get/get.dart';

class EmailLoginScreen extends StatelessWidget {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EmailAuthController());

    return AuthLayoutWrapper(
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // App Logo
          Hero(
            tag: 'app_logo',
            child: Image.asset(
              "assets/logo.png",
              height: 100,
              width: 100,
            ),
          ),
          
          const SizedBox(height: 30),

          // Email Login Card
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "EMAIL SIGN-IN",
                  style: ResponsiveText.heading2(context, color: TColor.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your email to get started with verification code!",
                  style: ResponsiveText.bodySmall(context, color: Colors.black54),
                ),
                
                const SizedBox(height: 30),

                // Email input
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    color: Colors.white.withOpacity(0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.email_outlined,
                          color: TColor.primary,
                          size: 22,
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
                      Expanded(
                        child: TextField(
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: ResponsiveText.body(context),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            hintText: "Enter email address",
                            hintStyle: ResponsiveText.hint(context),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: TColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Obx(
                      () => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: controller.isLoading.value
                            ? null
                            : () {
                                try {
                                  controller.requestOtp();
                                } catch (e) {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to process request: $e',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                }
                              },
                        child: controller.isLoading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                "Get Code",
                                style: ResponsiveText.button(context),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
