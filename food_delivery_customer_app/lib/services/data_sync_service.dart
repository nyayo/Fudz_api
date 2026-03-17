import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_delivery_customer_app/controller/category_controller.dart';
import 'package:food_delivery_customer_app/controller/promotion_controller.dart';
import 'package:food_delivery_customer_app/controller/restaurant_controller.dart';
import 'package:food_delivery_customer_app/services/connectivity_service.dart';
import 'package:get/get.dart';

/// Centralized data-sync service that keeps the UI fresh without manual refresh.
///
/// Strategies used:
/// 1. **Periodic polling** – silently re-fetches core lists every [_pollInterval].
/// 2. **Connectivity resume** – when the device goes back online a full sync fires immediately.
/// 3. **App lifecycle** – syncs when the app comes back to the foreground.
/// 4. **On-demand** – any screen can call [syncNow] for an instant refresh.
class DataSyncService extends GetxService with WidgetsBindingObserver {
  // ── Configuration ────────────────────────────────────────────────────
  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _minSyncGap = Duration(seconds: 10);

  // ── State ────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  DateTime? _lastSyncTime;
  final RxBool isSyncing = false.obs;
  Worker? _connectivityWorker;

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _listenToConnectivity();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _connectivityWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Fires when app goes to background / foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 DataSync: App resumed – triggering sync');
      syncNow();
    } else if (state == AppLifecycleState.paused) {
      // Pause polling while backgrounded to save battery.
      _pollTimer?.cancel();
    }
  }

  // ── Polling ──────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _silentSync());
  }

  // ── Connectivity listener ────────────────────────────────────────────

  void _listenToConnectivity() {
    if (!Get.isRegistered<ConnectivityService>()) return;
    final connectivity = Get.find<ConnectivityService>();

    _connectivityWorker = ever(connectivity.isConnected, (bool connected) {
      if (connected) {
        debugPrint('🔄 DataSync: Back online – triggering sync');
        syncNow();
        // Restart polling in case it was stopped
        _startPolling();
      }
    });
  }

  // ── Public API ───────────────────────────────────────────────────────

  /// Trigger an immediate sync (de-bounced by [_minSyncGap]).
  Future<void> syncNow() async {
    if (_shouldSkipSync()) return;
    await _performSync();
  }

  // ── Internal ─────────────────────────────────────────────────────────

  /// Silent sync used by the periodic timer – never shows errors to the user.
  Future<void> _silentSync() async {
    if (_shouldSkipSync()) return;
    try {
      await _performSync();
    } catch (_) {
      // Silent – don't disrupt the user for background failures.
    }
  }

  bool _shouldSkipSync() {
    if (isSyncing.value) return true;
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _minSyncGap) {
      return true;
    }
    // Don't sync if offline
    if (Get.isRegistered<ConnectivityService>()) {
      final connectivity = Get.find<ConnectivityService>();
      if (!connectivity.isConnected.value) return true;
    }
    return false;
  }

  Future<void> _performSync() async {
    isSyncing.value = true;
    _lastSyncTime = DateTime.now();

    try {
      final futures = <Future>[];

      // ── Restaurants & Menu items ──
      if (Get.isRegistered<RestaurantController>()) {
        final rc = Get.find<RestaurantController>();
        futures.add(rc.backgroundSync());
      }

      // ── Categories ──
      if (Get.isRegistered<CategoryController>()) {
        final cc = Get.find<CategoryController>();
        futures.add(cc.backgroundSync());
      }

      // ── Promotions ──
      if (Get.isRegistered<PromotionController>()) {
        final pc = Get.find<PromotionController>();
        futures.add(pc.loadPromotions());
      }

      await Future.wait(futures);
      debugPrint('✅ DataSync: sync complete (${DateTime.now()})');
    } catch (e) {
      debugPrint('❌ DataSync: sync error: $e');
    } finally {
      isSyncing.value = false;
    }
  }
}
