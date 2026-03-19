// services/token_service.dart
import 'package:food_delivery_customer_app/models/user.dart';
import 'package:get_storage/get_storage.dart';

class TokenService {
  final GetStorage _storage = GetStorage();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String tokenExpiryKey = 'token_expiry';
  static const String userKey = 'user_data';

  // Save tokens with proper expiry calculation
  Future<void> saveTokens(Map<String, dynamic> tokens) async {
    try {
      print('💾 Saving tokens: $tokens');
      
      // Handle different response formats
      final accessToken = _extractToken(tokens, 'access');
      final refreshToken = _extractToken(tokens, 'refresh');
      
      if (accessToken == null) {
        throw Exception('Access token is null');
      }

      await _storage.write(accessTokenKey, accessToken);
      
      // Only update refresh token if provided (some APIs don't return new refresh token)
      if (refreshToken != null) {
        await _storage.write(refreshTokenKey, refreshToken);
      }
      
      // Calculate expiry - SIMPLE_JWT access token is 15 minutes (900 seconds)
      // Backend doesn't return expires_in, so calculate from token lifetime
      const expiry = 900; // 15 minutes matching SIMPLE_JWT ACCESS_TOKEN_LIFETIME
      final expiryDuration = DateTime.now().add(const Duration(seconds: expiry));
      await _storage.write(tokenExpiryKey, expiryDuration.toIso8601String());
      
      print('✅ Tokens saved successfully');
      print('✅ Access token: ${accessToken.substring(0, 20)}...');
      if (refreshToken != null) {
        print('✅ Refresh token: ${refreshToken.substring(0, 20)}...');
      }
      print('✅ Expires at: $expiryDuration');
    } catch (e) {
      print('❌ Error saving tokens: $e');
      rethrow;
    }
  }

  // Helper to extract token from different response formats
  String? _extractToken(Map<String, dynamic> tokens, String tokenType) {
    final token = tokens[tokenType];
    
    if (token == null) return null;
    
    // Handle nested token structure (like {'access': {'token': 'xyz'}})
    if (token is Map) {
      return token['token'] ?? token[tokenType];
    }
    
    // Handle direct token string
    return token.toString();
  }

  Future<void> saveUserData(User user) async {
    await _storage.write(userKey, user.toJson());
  }

  User? getUserData() {
    final userData = _storage.read(userKey);
    if(userData != null){
      return User.fromJson(Map<String, dynamic>.from(userData));
    } else {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final token = _storage.read(accessTokenKey);
    return token;
  }

  Future<String?> getRefreshToken() async {
    final token = _storage.read(refreshTokenKey);
    return token;
  }

  Future<DateTime?> getExpiryDate() async {
    final expiry = _storage.read(tokenExpiryKey);
    if (expiry != null) {
      try {
        return DateTime.parse(expiry);
      } catch (e) {
        print('❌ Error parsing expiry date: $e');
        return null;
      }
    } else {
      return null;
    }
  }

  Future<void> clearTokens() async {
    await _storage.remove(accessTokenKey);
    await _storage.remove(refreshTokenKey);
    await _storage.remove(tokenExpiryKey);
    print('🗑️ Tokens cleared');
  }

  // Check if access token is expired
  Future<bool> isAccessTokenExpired() async {
    final expiryDate = await getExpiryDate();
    if (expiryDate == null) {
      return true;
    } else {
      final isExpired = DateTime.now().isAfter(expiryDate);
      print('⏰ Token expiry check: $expiryDate, isExpired: $isExpired');
      return isExpired;
    }
  }
}