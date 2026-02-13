import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/colors.dart';

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final RxBool isConnected = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final connected = results.any((r) => r != ConnectivityResult.none);
    final wasDisconnected = !isConnected.value;
    isConnected.value = connected;

    if (!connected) {
      _showNoConnectionBanner();
    } else if (wasDisconnected && connected) {
      _showReconnectedBanner();
    }
  }

  void _showNoConnectionBanner() {
    Get.snackbar(
      'No Internet Connection',
      'Please check your network settings and try again.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      icon: const Icon(Icons.wifi_off, color: Colors.white),
      duration: const Duration(seconds: 5),
      isDismissible: true,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }

  void _showReconnectedBanner() {
    Get.snackbar(
      'Back Online',
      'Your internet connection has been restored.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Icon(Icons.wifi, color: Colors.white),
      duration: const Duration(seconds: 3),
      isDismissible: true,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }

  /// Check if connected, showing a snackbar if not
  bool checkAndNotify() {
    if (!isConnected.value) {
      _showNoConnectionBanner();
      return false;
    }
    return true;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
