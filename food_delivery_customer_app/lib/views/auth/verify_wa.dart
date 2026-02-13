import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/views/auth/login.dart';
import 'package:food_delivery_customer_app/views/auth/verify_sms.dart';
import 'package:food_delivery_customer_app/views/screens/main_tab/main_tab_view.dart';

import 'package:get/get.dart';

class PhoneVerificationWaPage extends StatefulWidget {
  const PhoneVerificationWaPage({super.key});

  @override
  _PhoneVerificationWaPageState createState() =>
      _PhoneVerificationWaPageState();
}

class _PhoneVerificationWaPageState extends State<PhoneVerificationWaPage> {
  final int codeLength = 4;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  String phoneNumber = '+256764341463';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < codeLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled
    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyCode();
    }
  }

  void _verifyCode() {
    String verificationCode = _controllers.map((c) => c.text).join();
    // Here you would typically call your verification API
    debugPrint('Verification code: $verificationCode');

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Dismiss loading

      // Show result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verification Result'),
          content: Text('Code $verificationCode was submitted'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _resendCode() {
    debugPrint('Resend code requested');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New verification code sent'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: media.height * 0.08),

            GestureDetector(
              onTap: () {
                Get.to(LoginScreen());
              },
              child: Icon(Icons.arrow_back_ios),
            ),
            SizedBox(height: media.height * 0.04),
            Icon(
              FontAwesomeIcons.whatsapp,
              color: TColor.primary,
              size: media.width * 0.1,
            ),
            SizedBox(height: media.height * 0.03),
            const Text(
              'Enter Verification Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black54, fontSize: 16),
                children: [
                  const TextSpan(text: 'We sent a code via WhatsApp to \n'),
                  TextSpan(
                    text: phoneNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: media.height * 0.05),
            // Code input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                codeLength,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: SizedBox(
                    width: 50,
                    height: 60,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.all(10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: TColor.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _onChanged(value, index),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: media.height * 0.04),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // if (_controllers
                  //     .every((controller) => controller.text.isNotEmpty)) {
                  //   _verifyCode();
                  // } else {
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     const SnackBar(
                  //       content: Text('Please enter the complete code'),
                  //     ),
                  //   );
                  // }
                  Get.to(MainTabView());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColor.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Verify', style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(height: media.height * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resendCode,
                  child: Text(
                    "Resend Code",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: TColor.primary.withOpacity(0.8),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhoneVerificationSMSPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Send via SMS",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: TColor.primary.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
