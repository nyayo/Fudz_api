import 'dart:convert';
import 'package:get_storage/get_storage.dart';

/// Persistent cache service built on GetStorage.
/// Stores JSON data to disk and provides cache-first loading.
class CacheService {
  static final GetStorage _box = GetStorage();

  // Cache keys
  static const String _restaurantsKey = 'cache_restaurants';
  static const String _menuItemsKey = 'cache_menu_items';
  static const String _featuredItemsKey = 'cache_featured_items';
  static const String _categoriesKey = 'cache_categories';
  static const String _cartKey = 'cache_cart';
  static const String _timestampSuffix = '_timestamp';

  // ── Write ──────────────────────────────────────────────

  static Future<void> saveRestaurants(List<Map<String, dynamic>> data) async {
    await _box.write(_restaurantsKey, json.encode(data));
    await _box.write(
      '$_restaurantsKey$_timestampSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> saveMenuItems(List<Map<String, dynamic>> data) async {
    await _box.write(_menuItemsKey, json.encode(data));
    await _box.write(
      '$_menuItemsKey$_timestampSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> saveFeaturedItems(List<Map<String, dynamic>> data) async {
    await _box.write(_featuredItemsKey, json.encode(data));
    await _box.write(
      '$_featuredItemsKey$_timestampSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> saveCategories(List<dynamic> data) async {
    await _box.write(_categoriesKey, json.encode(data));
    await _box.write(
      '$_categoriesKey$_timestampSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── Read ───────────────────────────────────────────────

  static List<Map<String, dynamic>>? getRestaurants() {
    return _readList(_restaurantsKey);
  }

  static List<Map<String, dynamic>>? getMenuItems() {
    return _readList(_menuItemsKey);
  }

  static List<Map<String, dynamic>>? getFeaturedItems() {
    return _readList(_featuredItemsKey);
  }

  static List<dynamic>? getCategories() {
    final raw = _box.read(_categoriesKey);
    if (raw == null) return null;
    try {
      return json.decode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────

  static List<Map<String, dynamic>>? _readList(String key) {
    final raw = _box.read(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Check if cache exists for a given key.
  static bool hasCache(String key) {
    return _box.read(key) != null;
  }

  static bool get hasRestaurantsCache => _box.read(_restaurantsKey) != null;
  static bool get hasMenuItemsCache => _box.read(_menuItemsKey) != null;
  static bool get hasFeaturedItemsCache => _box.read(_featuredItemsKey) != null;

  /// Clear all cached data.
  static Future<void> clearAll() async {
    await _box.remove(_restaurantsKey);
    await _box.remove(_menuItemsKey);
    await _box.remove(_featuredItemsKey);
    await _box.remove(_categoriesKey);
    await _box.remove('$_restaurantsKey$_timestampSuffix');
    await _box.remove('$_menuItemsKey$_timestampSuffix');
    await _box.remove('$_featuredItemsKey$_timestampSuffix');
    await _box.remove('$_categoriesKey$_timestampSuffix');
  }
}
