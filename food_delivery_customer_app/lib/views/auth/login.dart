import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/views/screens/google_button.dart';
import 'package:food_delivery_customer_app/views/widgets/round_button.dart';
import 'package:food_delivery_customer_app/views/widgets/auth_layout_wrapper.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';
import 'package:get/get.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find<UserController>();

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

          // Main Login Content in Glass Card
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WELCOME TO FUDGON",
                  style: ResponsiveText.heading2(context, color: TColor.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  "Get your favorite meals delivered fast – start with your phone number!",
                  style: ResponsiveText.bodySmall(context, color: Colors.black54),
                ),
                
                const SizedBox(height: 30),

                // Phone input section (Improved)
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
                        child: Text(
                          "+256",
                          style: ResponsiveText.body(context, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.phone,
                          style: ResponsiveText.body(context),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            hintText: "Enter phone number",
                            hintStyle: ResponsiveText.hint(context),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Get Code link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: null, // As previously disabled
                    child: Text(
                      "Get Code",
                      style: TextStyle(
                        color: TColor.primary.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Social Dividers and Buttons
          Row(
            children: [
              const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Start with socials",
                  style: ResponsiveText.caption(context, color: Colors.white70),
                ),
              ),
              const Expanded(child: Divider(thickness: 1, color: Colors.white24)),
            ],
          ),

          const SizedBox(height: 24),

          // Google button
          Obx(
            () => GoogleSignInButton(
              onPressed: userController.isLoading.value
                  ? null
                  : () async {
                      try {
                        await userController.signInWithGoogle();
                      } catch (e) {
                        print('Google Sign-In error in UI: $e');
                      }
                    },
              isLoading: userController.isLoading.value,
            ),
          ),

          const SizedBox(height: 16),

          // Email Login button
          RoundButton(
            title: "Start with Email",
            onPressed: () {
              Get.toNamed('/email_login_screen');
            },
            bgcolor: TColor.primary.withOpacity(0.9),
            color1: Colors.white,
            icon: Icons.email_rounded,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
