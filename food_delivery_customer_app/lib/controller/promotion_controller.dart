import 'package:get/get.dart';
import 'package:food_delivery_customer_app/models/promo.dart';
import 'package:food_delivery_customer_app/services/api_service.dart';

class PromotionController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final RxList<Promotion> _promotions = <Promotion>[].obs;
  List<Promotion> get promotions => _promotions.toList();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxString _error = ''.obs;
  String get error => _error.value;

  @override
  void onInit() {
    super.onInit();
    loadPromotions();
  }

  Future<void> loadPromotions() async {
    try {
      print('═══════════════════════════════════════════════════');
      print('📦 PROMOTION CONTROLLER: Starting to load promotions...');
      
      _isLoading.value = true;
      _error.value = '';

      print('📡 Making API request to: restaurants/promotions/');
      dynamic response;
      try {
        response = await _apiService.get('restaurants/promotions/');
      } catch (_) {
        // Backward-compatible fallback if backend routing differs by environment.
        response = await _apiService.get('promotions/');
      }
      
      print('✅ API Response received');
      print('   Response type: ${response.runtimeType}');
      print('   Response: $response');

      if (response is Map) {
        print('⚠️  Response is a Map, checking for data/results key...');
        
        // Try to extract list from map
        if (response.containsKey('data') && response['data'] is List) {
          print('✅ Found "data" key with List');
          final list = response['data'] as List;
          _promotions.assignAll(
            list.map((json) => Promotion.fromJson(json)).toList(),
          );
          print('✅ Loaded ${_promotions.length} promotions from "data" key');
        } else if (response.containsKey('results') && response['results'] is List) {
          print('✅ Found "results" key with List');
          final list = response['results'] as List;
          _promotions.assignAll(
            list.map((json) => Promotion.fromJson(json)).toList(),
          );
          print('✅ Loaded ${_promotions.length} promotions from "results" key');
        } else {
          print('❌ Response is Map but no "data" or "results" key found');
          print('   Available keys: ${response.keys.toList()}');
          _error.value = 'Invalid response format - no data or results key';
        }
      } else if (response is List) {
        print('✅ Response is a List directly');
        _promotions.assignAll(
          response.map((json) => Promotion.fromJson(json)).toList(),
        );
        print('✅ Loaded ${_promotions.length} promotions');
      } else {
        print('❌ Unexpected response type: ${response.runtimeType}');
        _error.value = 'Invalid response format - expected List or Map';
      }
      
      // Log active vs inactive promotions
      final active = _promotions.where((p) => p.isActive).length;
      final inactive = _promotions.length - active;
      print('📊 Promotion Summary:');
      print('   Total: ${_promotions.length}');
      print('   Active: $active');
      print('   Inactive: $inactive');
      
      if (_promotions.isNotEmpty) {
        print('📋 Promotion List:');
        for (var promo in _promotions) {
          print('   - ID: ${promo.id}, Name: ${promo.name}, Active: ${promo.isActive}');
        }
      }
      
      print('═══════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      _error.value = 'Failed to load promotions: $e';
      print('═══════════════════════════════════════════════════');
      print('❌ PROMOTION CONTROLLER ERROR:');
      print('   Error: $e');
      print('   Stack trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> refreshPromotions() async {
    await loadPromotions();
  }

  List<Promotion> get activePromotions {
    return _promotions.where((promo) => promo.isCurrentlyActive).toList();
  }

  Promotion? getPromotionById(int id) {
    return _promotions.firstWhereOrNull((promo) => promo.id == id);
  }
}
