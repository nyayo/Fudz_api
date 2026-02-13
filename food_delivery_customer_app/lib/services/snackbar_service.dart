// services/snackbar_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarService {
  static final SnackbarService _instance = SnackbarService._internal();
  factory SnackbarService() => _instance;
  SnackbarService._internal();

  static void show({
    required String message,
    String? title,
    Color backgroundColor = Colors.green,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool showProgress = false,
  }) {
    // Clear any existing snackbars
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    Get.snackbar(
      title ?? 'Notification',
      message,
      titleText: title != null 
          ? Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            )
          : null,
      messageText: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProgress) ...[
            const LinearProgressIndicator(
              backgroundColor: Colors.white30,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor.withOpacity(0.9),
      duration: duration,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      colorText: Colors.white,
      mainButton: action != null 
          ? TextButton(
              onPressed: () {
                action.onPressed();
                            },
              child: Text(
                action.label,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
    );
  }

  // Convenience methods for common snackbar types
  static void showSuccess(String message, {String? title}) {
    show(
      title: title ?? 'Success',
      message: message,
      backgroundColor: Colors.green,
    );
  }

  static void showError(String message, {String? title}) {
    show(
      title: title ?? 'Error',
      message: message,
      backgroundColor: Colors.red,
    );
  }

  static void showInfo(String message, {String? title}) {
    show(
      title: title ?? 'Info',
      message: message,
      backgroundColor: Colors.blue,
    );
  }

  static void showWarning(String message, {String? title}) {
    show(
      title: title ?? 'Warning',
      message: message,
      backgroundColor: Colors.orange,
    );
  }

  static void showLoading(String message) {
    show(
      message: message,
      backgroundColor: Colors.blue,
      showProgress: true,
      duration: const Duration(minutes: 1), // Long duration for loading
    );
  }

  static void hide() {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
  }
}
