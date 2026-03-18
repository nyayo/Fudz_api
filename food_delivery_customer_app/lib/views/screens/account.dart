// lib/views/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/models/user.dart';
import 'package:food_delivery_customer_app/views/screens/edit_profile.dart';
import 'package:food_delivery_customer_app/views/screens/notification_preferences_page.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:get/get.dart';
import 'package:food_delivery_customer_app/utils/text_styles.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find<UserController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header
              FadeSlideIn(
                duration: const Duration(milliseconds: 500),
                child: _buildHeader(),
              ),
              const SizedBox(height: 32),

              // Wrap the main content in Obx to react to user changes
              Obx(() {
                final user = userController.user;
                final isLoggedIn = userController.isLoggedIn;

                return Column(
                  children: [
                    // Profile Card
                    FadeSlideIn(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      child: _buildProfileCard(user, isLoggedIn),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Section
                    if (isLoggedIn)
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 200),
                        child: _buildPersonalInfoSection(user),
                      ),
                    if (isLoggedIn) const SizedBox(height: 24),

                    // Account Information Section
                    if (isLoggedIn)
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 300),
                        child: _buildAccountInfoSection(user),
                      ),
                    if (isLoggedIn) const SizedBox(height: 24),

                    // Google Account Linking Section
                    if (isLoggedIn && !_isPrimaryGoogleAccount(user, userController))
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 350),
                        child: _buildGoogleLinkSection(userController),
                      ),
                    if (isLoggedIn && !_isPrimaryGoogleAccount(user, userController))
                      const SizedBox(height: 24),

                    // Notification Preferences
                    if (isLoggedIn)
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 400),
                        child: _buildNotificationPreferencesButton(),
                      ),
                    if (isLoggedIn) const SizedBox(height: 32),

                    // Logout Button
                    if (isLoggedIn)
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        delay: const Duration(milliseconds: 500),
                        child: _buildLogoutButton(userController),
                      ),

                    // Show login prompt if not logged in
                    if (!isLoggedIn)
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        child: _buildLoginPrompt(),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) =>
                  Text('My Profile', style: ResponsiveText.heading1(context)),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) => Text(
                'Manage your personal information',
                style: ResponsiveText.bodySmall(
                  context,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: TColor.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(Icons.person_outline, color: TColor.primary, size: 24),
        ),
      ],
    );
  }

  Widget _buildProfileCard(User? user, bool isLoggedIn) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TColor.primary.withOpacity(0.8), TColor.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TColor.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) => Text(
                    isLoggedIn ? user?.displayName ?? 'User' : 'Guest User',
                    style: ResponsiveText.heading2(
                      context,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) => Text(
                    isLoggedIn ? user?.email ?? 'User' : 'Login to continue',
                    style: ResponsiveText.bodySmall(
                      context,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                if (isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Builder(
                      builder: (context) => Text(
                        user?.userType.toUpperCase() ?? 'USER',
                        style: ResponsiveText.caption(
                          context,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Edit Button (only show when logged in)
          if (isLoggedIn)
            IconButton(
              onPressed: () {
                Get.to(() => const EditProfilePage());
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(User? user) {
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
          Row(
            children: [
              Icon(Icons.person_outline, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Full Name',
            Text(
              user?.fullName.isNotEmpty == true ? user!.fullName : 'Not set',
              style: TextStyle(
                fontSize: 16,
                color: user?.fullName.isNotEmpty == true
                    ? TColor.primaryText
                    : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.person,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Phone Number',
            Text(
              user?.phone.isNotEmpty == true
                  ? _formatPhoneNumber(user!.phone)
                  : 'Not set',
              style: TextStyle(
                fontSize: 16,
                color: user?.phone.isNotEmpty == true
                    ? TColor.primaryText
                    : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.phone,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Username',
            Text(
              '@${user?.username ?? 'Not set'}',
              style: TextStyle(
                fontSize: 16,
                color: TColor.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.alternate_email,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection(User? user) {
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
          Row(
            children: [
              Icon(Icons.security_outlined, color: TColor.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TColor.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Email Address',
            Text(
              user?.email ?? 'Not set',
              style: TextStyle(
                fontSize: 16,
                color: TColor.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.email_outlined,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Account Status',
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: user?.isVerified == true
                        ? Colors.green
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  user?.isVerified == true
                      ? 'Verified'
                      : 'Pending Verification',
                  style: TextStyle(
                    fontSize: 16,
                    color: user?.isVerified == true
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icons.verified_outlined,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Member Since',
            Text(
              user?.createdAt != null
                  ? _formatDate(user!.createdAt!)
                  : 'Not available',
              style: TextStyle(
                fontSize: 16,
                color: TColor.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'User Type',
            Text(
              _formatUserType(user?.userType ?? 'customer'),
              style: TextStyle(
                fontSize: 16,
                color: TColor.primaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icons.badge_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLinkSection(UserController userController) {
    return Obx(() {
      final isLinked = userController.isGoogleLinked.value;
      final isLinking = userController.isLinkingGoogle.value;

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
            Row(
              children: [
                Icon(Icons.link, color: TColor.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Linked Accounts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TColor.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Google icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLinked
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/google_icon.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.g_mobiledata,
                        color: isLinked ? Colors.green : Colors.grey,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: TColor.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLinked
                            ? 'Linked — you can sign in with Google'
                            : 'Not linked — tap to connect',
                        style: TextStyle(
                          fontSize: 13,
                          color: isLinked ? Colors.green : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Link / Unlink button
                if (isLinking)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _buildGoogleLinkButton(isLinked, userController),
              ],
            ),
          ],
        ),
      );
    });
  }

  bool _isPrimaryGoogleAccount(User? user, UserController userController) {
    return user?.googleLinked == true && userController.isGoogleLinked.value;
  }

  Widget _buildGoogleLinkButton(bool isLinked, UserController userController) {
    if (isLinked) {
      return TextButton(
        onPressed: () => _showUnlinkConfirmation(userController),
        style: TextButton.styleFrom(
          foregroundColor: Colors.red[400],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Unlink',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => userController.linkGoogleAccount(),
      style: ElevatedButton.styleFrom(
        backgroundColor: TColor.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: const Text(
        'Link',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showUnlinkConfirmation(UserController userController) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unlink Google?'),
          ],
        ),
        content: const Text(
          'You will no longer be able to sign in with Google. '
          'Make sure you have another way to access your account (email/phone).',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: TColor.primaryText)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              userController.unlinkGoogleAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, Widget value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TColor.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: TColor.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              value,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationPreferencesButton() {
    return GestureDetector(
      onTap: () {
        Get.to(() => const NotificationPreferencesPage());
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: TColor.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TColor.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your notification settings',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(UserController userController) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _showLogoutConfirmation(userController);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Icon(Icons.login, size: 64, color: TColor.primary),
          const SizedBox(height: 16),
          Text(
            'Login Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TColor.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please login to view your profile information',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.toNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TColor.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Login Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(UserController userController) {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          Obx(
            () => TextButton(
              onPressed: userController.isLoading.value
                  ? null
                  : () => Get.back(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: userController.isLoading.value
                      ? Colors.grey
                      : TColor.primaryText,
                ),
              ),
            ),
          ),
          Obx(
            () => TextButton(
              onPressed: userController.isLoading.value
                  ? null
                  : () {
                      userController.logout();
                    },
              style: TextButton.styleFrom(
                foregroundColor: userController.isLoading.value
                    ? Colors.grey
                    : Colors.red,
              ),
              child: userController.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    return phone;
  }

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatUserType(String userType) {
    switch (userType.toLowerCase()) {
      case 'customer':
        return 'Customer';
      case 'vendor':
        return 'Restaurant Owner';
      case 'driver':
        return 'Delivery Driver';
      default:
        return userType;
    }
  }
}
