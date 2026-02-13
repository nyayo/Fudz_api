import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/views/widgets/animation_helpers.dart';
import 'package:food_delivery_customer_app/constants/colors.dart';
import 'package:food_delivery_customer_app/controller/user_controller.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';
import 'package:food_delivery_customer_app/views/widgets/connectivity_widgets.dart';
import 'package:get/get.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final ApiService _apiService = Get.find<ApiService>();
  final UserController _userController = Get.find<UserController>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Preference values
  bool _receivePush = true;
  bool _receiveEmail = true;
  bool _promotionsAndOffers = true;
  bool _newRestaurants = true;
  bool _reviewReminders = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get(
        'users/auth/notification-preferences/',
      );

      if (response is Map<String, dynamic>) {
        setState(() {
          _receivePush = response['receive_push'] ?? true;
          _receiveEmail = response['receive_email'] ?? true;
          _promotionsAndOffers = response['promotions_and_offers'] ?? true;
          _newRestaurants = response['new_restaurants'] ?? true;
          _reviewReminders = response['review_reminders'] ?? true;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);

    try {
      await _apiService.patch('users/auth/notification-preferences/', {
        'receive_push': _receivePush,
        'receive_email': _receiveEmail,
        'promotions_and_offers': _promotionsAndOffers,
        'new_restaurants': _newRestaurants,
        'review_reminders': _reviewReminders,
      });

      Get.snackbar(
        'Saved',
        'Notification preferences updated successfully.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        sanitizeErrorMessage(e.toString()),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Notification Preferences',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: TColor.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: TColor.primary));
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        errorMessage: _error,
        onRetry: _loadPreferences,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // General Notifications
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('General', Icons.notifications_outlined),
                const SizedBox(height: 12),
                _buildPreferenceCard(
            children: [
              _buildSwitchTile(
                title: 'Push Notifications',
                subtitle: 'Receive push notifications on your device',
                icon: Icons.phone_android,
                value: _receivePush,
                onChanged: (val) {
                  setState(() => _receivePush = val);
                  _savePreferences();
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'Email Notifications',
                subtitle: 'Receive notifications via email',
                icon: Icons.email_outlined,
                value: _receiveEmail,
                onChanged: (val) {
                  setState(() => _receiveEmail = val);
                  _savePreferences();
                },
              ),
            ],
          ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notification Types
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Notification Types', Icons.tune),
          const SizedBox(height: 12),
          _buildPreferenceCard(
            children: [
              _buildSwitchTile(
                title: 'Promotions & Offers',
                subtitle: 'Get notified about deals and discounts',
                icon: Icons.local_offer_outlined,
                value: _promotionsAndOffers,
                onChanged: (val) {
                  setState(() => _promotionsAndOffers = val);
                  _savePreferences();
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'New Restaurants',
                subtitle: 'Be the first to know about new restaurants',
                icon: Icons.restaurant_outlined,
                value: _newRestaurants,
                onChanged: (val) {
                  setState(() => _newRestaurants = val);
                  _savePreferences();
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: 'Review Reminders',
                subtitle: 'Remind me to rate my orders',
                icon: Icons.rate_review_outlined,
                value: _reviewReminders,
                onChanged: (val) {
                  setState(() => _reviewReminders = val);
                  _savePreferences();
                },
              ),
            ],
          ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Info footer
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order updates and important account notifications will always be sent regardless of these settings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: TColor.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: TColor.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TColor.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: TColor.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: TColor.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: TColor.primary,
          ),
        ],
      ),
    );
  }
}
