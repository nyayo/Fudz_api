// lib/views/screens/registration_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:get/get.dart';

import 'package:food_delivery_customer_app/controller/registration_controller.dart';

class RegistrationPage extends StatelessWidget {
  RegistrationPage({super.key});

  final RegistrationController _controller = Get.find<RegistrationController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => Get.back(),
                icon: Icon(Icons.arrow_back, color: TColor.primaryText),
              ),
              const SizedBox(height: 20),

              // Header
              Text(
                'Complete Registration',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your details to complete registration',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Registration Form
              _buildRegistrationForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Phone section (shown first for phone flow) ──
          Obx(() {
            if (_controller.fromPhone) {
              return _buildReadOnlyField(
                'Phone Number (verified)',
                _controller.phone ?? '',
                Icons.phone,
              );
            }
            return TextFormField(
              controller: _controller.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone, color: TColor.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // First Name
          TextFormField(
            controller: _controller.firstNameController,
            decoration: InputDecoration(
              labelText: 'First Name',
              prefixIcon: Icon(Icons.person_outline, color: TColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Last Name
          TextFormField(
            controller: _controller.lastNameController,
            decoration: InputDecoration(
              labelText: 'Last Name',
              prefixIcon: Icon(Icons.person_outline, color: TColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Email section ──
          // If from phone flow: editable email + inline verify
          // If from email flow: read-only (already verified)
          Obx(() {
            if (_controller.isEmailVerified.value && !_controller.fromPhone) {
              // Came from email OTP – show read-only
              return _buildReadOnlyField(
                'Email Address',
                _controller.email ?? _controller.emailController.text,
                Icons.email_outlined,
              );
            }
            // Phone-first or email not yet verified
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email input + verify button
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_controller.isEmailVerified.value,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon:
                              Icon(Icons.email_outlined, color: TColor.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: _controller.isEmailVerified.value
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                        ),
                      ),
                    ),
                    if (!_controller.isEmailVerified.value) ...[
                      const SizedBox(width: 8),
                      Obx(
                        () => ElevatedButton(
                          onPressed: _controller.isSendingOtp.value
                              ? null
                              : () => _controller.requestEmailOtp(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TColor.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _controller.isSendingOtp.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Verify',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ],
                ),

                // Inline OTP fields
                if (_controller.showOtpFields.value &&
                    !_controller.isEmailVerified.value) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Enter the 6-digit code sent to your email',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 42,
                        height: 48,
                        child: TextField(
                          controller: _controller.otpControllers[index],
                          focusNode: _controller.otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.grey[50],
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: TColor.primary, width: 2),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _controller.otpFocusNodes[index + 1]
                                  .requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _controller.otpFocusNodes[index - 1]
                                  .requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _controller.isVerifyingEmail.value
                            ? null
                            : () => _controller.verifyEmailOtp(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TColor.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _controller.isVerifyingEmail.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Verify Email',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _controller.passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: TColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _controller.confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline, color: TColor.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Register Button
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _controller.isLoading.value
                    ? null
                    : () => _controller.registerUser(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _controller.isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Complete Registration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: TColor.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
