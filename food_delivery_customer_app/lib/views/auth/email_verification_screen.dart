import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/email_auth_controller.dart';

import 'package:get/get.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EmailAuthController>();
    final String email = Get.arguments as String;
    final media = MediaQuery.of(context).size;
    final isSmallScreen = media.height < 700;

    return Scaffold(
      body: Container(
        width: media.width,
        height: media.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/login_image.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isSmallScreen ? 10 : 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    media.height - MediaQuery.of(context).padding.vertical,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: media.height * 0.05),

                  // Main content container
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "VERIFY YOUR EMAIL",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 22 : 28,
                                fontWeight: FontWeight.bold,
                                color: TColor.primary,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Text(
                              "Enter the 6-digit code sent to",
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.7),
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: TColor.primary,
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        SizedBox(height: isSmallScreen ? 20 : 30),

                        // OTP Input Fields
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            final otpFieldSize = availableWidth < 350
                                ? 40.0
                                : 50.0;
                            final otpSpacing = availableWidth < 350 ? 6.0 : 8.0;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) {
                                return SizedBox(
                                  width: otpFieldSize,
                                  height: otpFieldSize + 10,
                                  child: TextField(
                                    controller:
                                        controller.otpControllers[index],
                                    focusNode: controller.focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: "",
                                      filled: true,
                                      fillColor: Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: TColor.primary,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        controller.focusNodes[index + 1]
                                            .requestFocus();
                                      } else if (value.isEmpty && index > 0) {
                                        controller.focusNodes[index - 1]
                                            .requestFocus();
                                      }

                                      if (controller.isOtpComplete()) {
                                        FocusScope.of(context).unfocus();
                                      }
                                    },
                                  ),
                                );
                              }),
                            );
                          },
                        ),

                        SizedBox(height: isSmallScreen ? 25 : 35),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          child: Obx(
                            () => ElevatedButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : () => controller.verifyOtp(email),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TColor.primary,
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: controller.isLoading.value
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      "Verify Code",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 15 : 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 15 : 20),

                        // Resend Code Section
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                              Obx(
                                () => TextButton(
                                  onPressed: controller.isResending.value
                                      ? null
                                      : () => controller.resendOtp(email),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(50, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: controller.isResending.value
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  TColor.primary,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          "Resend",
                                          style: TextStyle(
                                            color: TColor.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 13 : 14,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: media.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
