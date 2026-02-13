// Create a new file: services/order_storage_service.dart
import 'package:get_storage/get_storage.dart';

class OrderStorageService {
  final GetStorage _storage = GetStorage();

  static const String _orderLocationsKey = 'order_locations';

  Future<void> saveOrderLocation(int orderId, Map<String, dynamic> locationData) async {
    final locations = _storage.read(_orderLocationsKey) ?? {};
    locations[orderId.toString()] = locationData;
    await _storage.write(_orderLocationsKey, locations);
    print('💾 Saved location for order $orderId: $locationData');
  }

  Map<String, dynamic>? getOrderLocation(int orderId) {
    final locations = _storage.read(_orderLocationsKey) ?? {};
    final location = locations[orderId.toString()];
    print('💾 Retrieved location for order $orderId: $location');
    return location;
  }

  Future<void> clearOrderLocations() async {
    await _storage.remove(_orderLocationsKey);
    print('💾 Cleared all order locations');
  }
}