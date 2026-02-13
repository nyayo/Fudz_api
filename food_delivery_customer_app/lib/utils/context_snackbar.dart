// utils/context_snackbar.dart
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/services/snackbar_service.dart';

class ContextSnackbar {
  static void showSuccess(BuildContext context, String message) {
    SnackbarService.showSuccess(message);
  }

  static void showError(BuildContext context, String message) {
    SnackbarService.showError(message);
  }

  static void showInfo(BuildContext context, String message) {
    SnackbarService.showInfo(message);
  }

  static void showWarning(BuildContext context, String message) {
    SnackbarService.showWarning(message);
  }
}