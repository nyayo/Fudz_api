// views/screens/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/user.dart';
import 'package:get/get.dart';

class EditProfilePage extends StatefulWidget {
  final String? initialField;

  const EditProfilePage({super.key, this.initialField});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserController _userController = Get.find<UserController>();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _userController.user;

    _firstNameController = TextEditingController(text: _resolveFirstName(user));
    _lastNameController = TextEditingController(text: _resolveLastName(user));
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    // Ensure we also prefill from the latest backend profile when cache is stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileForPrefill();
    });

    // Auto-focus on the specified field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialField != null) {
        switch (widget.initialField) {
          case 'name':
            _firstNameFocus.requestFocus();
            break;
          case 'phone':
            _phoneFocus.requestFocus();
            break;
          case 'email':
            _emailFocus.requestFocus();
            break;
        }
      }
    });
  }

  Future<void> _refreshProfileForPrefill() async {
    try {
      await _userController.getProfile();
      if (!mounted) return;

      final refreshedUser = _userController.user;
      final first = _resolveFirstName(refreshedUser);
      final last = _resolveLastName(refreshedUser);

      if (_firstNameController.text.trim().isEmpty && first.isNotEmpty) {
        _firstNameController.text = first;
      }
      if (_lastNameController.text.trim().isEmpty && last.isNotEmpty) {
        _lastNameController.text = last;
      }
      if (_phoneController.text.trim().isEmpty &&
          (refreshedUser?.phone ?? '').trim().isNotEmpty) {
        _phoneController.text = refreshedUser!.phone;
      }
      if (_emailController.text.trim().isEmpty &&
          (refreshedUser?.email ?? '').trim().isNotEmpty) {
        _emailController.text = refreshedUser!.email;
      }
    } catch (_) {
      // Keep currently displayed cached values if profile refresh fails.
    }
  }

  String _resolveFirstName(User? user) {
    final direct = (user?.firstName ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final fromProfile = (user?.profile?['first_name'] ?? '').toString().trim();
    if (fromProfile.isNotEmpty) return fromProfile;

    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty && !display.contains('@') && display.contains(' ')) {
      return display.split(RegExp(r'\s+')).first;
    }

    return '';
  }

  String _resolveLastName(User? user) {
    final direct = (user?.lastName ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final fromProfile = (user?.profile?['last_name'] ?? '').toString().trim();
    if (fromProfile.isNotEmpty) return fromProfile;

    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty && !display.contains('@') && display.contains(' ')) {
      final parts = display.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.sublist(1).join(' ');
      }
    }

    return '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // Helper method to format phone number to international format
  String _formatPhoneNumber(String phone) {
    // Remove all spaces, parentheses, dashes, etc.
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If already starts with +, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // If starts with 0 (local Kenyan format), replace with +254
    if (cleaned.startsWith('0')) {
      return '+256${cleaned.substring(1)}';
    }

    // If starts with 254, add +
    if (cleaned.startsWith('254')) {
      return '+$cleaned';
    }

    // Default: assume Kenyan and add +254
    return '+256$cleaned';
  }

  // In edit_profile_page.dart - update the _updateProfile method
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format phone number to international format
      String? formattedPhone;
      String phoneInput = _phoneController.text.trim();
      if (phoneInput.isNotEmpty) {
        formattedPhone = _formatPhoneNumber(phoneInput);
        print('📱 Phone formatted: $phoneInput -> $formattedPhone');
      }

      // Prepare update data
      final updateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': formattedPhone,
      };

      print('📝 Attempting to update profile with cleaned data: $updateData');

      // Call the update method from user controller
      final success = await _userController.updateUserProfile(updateData);

      if (success) {
        Get.back();
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      print('❌ Update profile error: $e');
      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString().replaceAll('Exception: ', '')}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  // In edit_profile_page.dart - update the _validatePhone method
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }

    // More flexible phone validation that accepts various formats
    final phoneRegex = RegExp(r'^[\+]?[0-9\s\-\(\)]{8,20}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number (8-20 digits)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: TColor.primaryText,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Picture Section
                FadeSlideIn(child: _buildProfilePictureSection()),
                const SizedBox(height: 30),

                // Personal Information Form
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: _buildPersonalInfoForm(),
                ),
                const SizedBox(height: 30),

                // Update Button
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TColor.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _updateProfile,
                      child: _isLoading
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
                          : const Text(
                              'Update Profile',
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
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        // Profile Picture
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: TColor.primary.withOpacity(0.2),
              width: 2,
            ),
            color: TColor.primary.withOpacity(0.1),
          ),
          child: Icon(Icons.person, size: 50, color: TColor.primary),
        ),
        const SizedBox(height: 15),

        // Change Photo Button
        TextButton(
          onPressed: () {
            // TODO: Implement photo change functionality
            Get.snackbar(
              'Coming Soon',
              'Photo upload feature will be available soon',
              snackPosition: SnackPosition.TOP,
            );
          },
          child: Text(
            'Change Photo',
            style: TextStyle(
              color: TColor.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoForm() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // First Name
          _buildFormField(
            controller: _firstNameController,
            focusNode: _firstNameFocus,
            label: 'First Name',
            icon: Icons.person,
            validator: _validateName,
          ),
          const SizedBox(height: 16),

          // Last Name
          _buildFormField(
            controller: _lastNameController,
            focusNode: _lastNameFocus,
            label: 'Last Name',
            icon: Icons.person_outline,
            validator: _validateName,
          ),
          const SizedBox(height: 16),

          // Phone Number
          _buildFormField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            label: 'Phone Number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),

          // Email
          _buildFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            label: 'Email Address',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            readOnly: true, // Email might not be editable after registration
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TColor.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: TColor.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[50] : Colors.white,
      ),
      validator: validator,
    );
  }
}
