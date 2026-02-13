import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_customer_app/views/auth/login.dart';
import 'package:food_delivery_customer_app/views/widgets/auth_layout_wrapper.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';
import 'package:get/get.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayoutWrapper(
      backgroundImage: "assets/start_image.png",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Logo with subtle shadow
          Hero(
            tag: 'app_logo',
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                "assets/logo.png",
                height: 120,
                width: 120,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Welcome Card
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Text(
                  "Welcome",
                  style: ResponsiveText.heading1(context, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Your Favorite Food, Delivered Fast!",
                  style: ResponsiveText.bodySmall(context, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Get.to(
                        () => LoginScreen(),
                        transition: Transition.rightToLeftWithFade,
                        duration: const Duration(milliseconds: 400),
                      );
                    },
                    child: Text(
                      "Get Started",
                      style: ResponsiveText.button(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Optional Footer Text
          Text(
            "Powered by FUDZ",
            style: ResponsiveText.tiny(context, color: Colors.white70),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
