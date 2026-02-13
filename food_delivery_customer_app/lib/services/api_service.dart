import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:food_delivery_customer_app/services/error_logger_service.dart';
import 'package:food_delivery_customer_app/services/token_service.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class ApiService extends GetxService {
  static const String baseUrl = 'http://129.151.165.133/api/v1';
  final GetStorage _storage = GetStorage();
  final http.Client client = http.Client();
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;
  final TokenService _tokenService = TokenService();
  ErrorLoggerService? _errorLogger;

  @override
  void onInit() {
    super.onInit();
    // Get error logger if available
    if (Get.isRegistered<ErrorLoggerService>()) {
      _errorLogger = Get.find<ErrorLoggerService>();
    }
  }

// In ApiService, update the _sendRequest method
Future<dynamic> _sendRequest(Future<http.Response> Function() requestFunc, {int retryCount = 0, String? endpoint}) async {
  try {
    final response = await requestFunc();
    
    // If we get a successful response, handle it normally
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return await handleResponse(response);
    }
    
    // If we get a 401/403, try to refresh token and retry
    if (response.statusCode == 401 || response.statusCode == 403) {
      final responseBody = response.body.toLowerCase();
      if (responseBody.contains('token') && 
          (responseBody.contains('expired') || responseBody.contains('invalid'))) {
        
        if (retryCount < 1) { // Only retry once to avoid infinite loops
          print('🔄 Token expired in API call, refreshing and retrying...');
          final refreshed = await refreshToken();
          
          if (refreshed) {
            print('✅ Token refreshed, retrying request (attempt ${retryCount + 1})');
            return await _sendRequest(requestFunc, retryCount: retryCount + 1);
          } else {
            print('❌ Token refresh failed during API call');
            Get.offAllNamed('/login');
            throw Exception('Session expired. Please login again.');
          }
        } else {
          print('❌ Max retries reached for token refresh');
          throw Exception('Authentication failed after retry');
        }
      }
    }
    
    // For other errors, handle normally
    return await handleResponse(response, endpoint: endpoint);
  } catch (e, stackTrace) {
    // Log the error
    _errorLogger?.logBackendError(
      message: 'API request failed',
      endpoint: endpoint,
      error: e,
      stackTrace: stackTrace,
    );
    
    // Check if this is a "token refreshed - retry" exception
    if (e.toString().contains('Token refreshed - please retry request')) {
      if (retryCount < 1) {
        print('🔄 Retrying request after token refresh...');
        return await _sendRequest(requestFunc, retryCount: retryCount + 1, endpoint: endpoint);
      } else {
        throw Exception('Failed after token refresh retry');
      }
    }
    
    rethrow;
  }
}

  // In ApiService, update the handleResponse method
Future<dynamic> handleResponse(http.Response response, {String? endpoint}) async {
  print('API Response - Status: ${response.statusCode}, URL: ${response.request?.url}');
  
  if (response.statusCode >= 200 && response.statusCode < 300) {
    if (response.body.isEmpty) return {};
    
    try {
      final decodedResponse = json.decode(response.body);
      print('API Success Response Type: ${decodedResponse.runtimeType}');
      
      // Handle both List and Map responses
      if (decodedResponse is List) {
        print('API returned List with ${decodedResponse.length} items');
        return {'data': decodedResponse};
      } else if (decodedResponse is Map) {
        print('API returned Map');
        return decodedResponse;
      } else {
        print('API returned unexpected type: ${decodedResponse.runtimeType}');
        return {'data': decodedResponse};
      }
    } catch (e) {
      print('JSON Parse Error: $e');
      throw Exception('Failed to parse response: $e');
    }
  } else if (response.statusCode == 401 || response.statusCode == 403) {
    print('API ${response.statusCode} Unauthorized/Forbidden - Token might be expired');
    
    // Check if this is a token-related error
    final responseBody = response.body.toLowerCase();
    if (responseBody.contains('token') && 
        (responseBody.contains('expired') || 
         responseBody.contains('invalid') || 
         responseBody.contains('not valid'))) {
      
      print('🔄 Token expired/invalid, attempting refresh...');
      final refreshed = await refreshToken();
      
      if (refreshed) {
        print('✅ Token refreshed successfully, retrying original request');
        throw Exception('Token refreshed - please retry request');
      } else {
        print('❌ Token refresh failed, redirecting to login');
        Get.offAllNamed('/login');
        throw Exception('Session expired. Please login again.');
      }
    } else {
      // It's a different 403 error (not token-related)
      print('API Error - Status: ${response.statusCode}, Body: ${response.body}');
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? error['message'] ?? error['error'] ?? 'Something went wrong');
      } catch (e) {
        throw Exception('Something went wrong (Status: ${response.statusCode})');
      }
    }
  } else if (response.statusCode == 404) {
    print('API 404 Not Found - Endpoint: ${response.request?.url}');
    print('⚠️ Endpoint not found, returning empty data');
    return {};
  } else {
    print('API Error - Status: ${response.statusCode}, Body: ${response.body}');
    
    // Log detailed backend error
    _errorLogger?.logBackendError(
      message: 'Backend returned error response',
      endpoint: endpoint ?? response.request?.url.toString(),
      statusCode: response.statusCode,
      responseBody: response.body,
    );
    
    try {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? error['message'] ?? error['error'] ?? 'Something went wrong');
    } catch (e) {
      throw Exception('Something went wrong (Status: ${response.statusCode})');
    }
  }
}

  // In ApiService, update the refreshToken method
Future<bool> refreshToken() async {
  if (_isRefreshing) {
    _logDebug('Refresh already in progress, waiting for completion');
    try {
      if (_refreshCompleter != null) await _refreshCompleter!.future;
    } catch (e, st) {
      _logError('Waiting for refresh failed', e, st);
    }

    final tokenAfterWait = await _tokenService.getAccessToken();
    return tokenAfterWait != null;
  }

  _isRefreshing = true;
  _refreshCompleter = Completer<void>();

  try {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null) {
      _logDebug('No refresh token available');
      return false;
    }

    // Use the correct endpoint
    final uri = Uri.parse('$baseUrl/users/auth/token/refresh/');

    _logDebug('Attempting token refresh at: $uri');

    final response = await client
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh': refreshToken}),
    )
        .timeout(const Duration(seconds: 10));

    _logDebug('Token refresh response status: ${response.statusCode}');
    _logDebug('Token refresh response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Handle different response formats
      Map<String, dynamic> tokens = {};
      
      if (data is Map) {
        // Standard format: {'access': 'token', 'refresh': 'token'}
        if (data.containsKey('access')) {
          tokens['access'] = data['access'];
        }
        if (data.containsKey('refresh')) {
          tokens['refresh'] = data['refresh'];
        }
        // Some APIs return 'access_token' instead of 'access'
        if (data.containsKey('access_token')) {
          tokens['access'] = data['access_token'];
        }
        if (data.containsKey('refresh_token')) {
          tokens['refresh'] = data['refresh_token'];
        }
      }
      
      // If we got an access token, save it
      if (tokens.containsKey('access')) {
        await _tokenService.saveTokens(tokens);
        _logDebug('✅ Token refresh succeeded');
        return true;
      } else {
        _logError('No access token in refresh response', null);
        return false;
      }
    }

    // Handle different error responses
    if (response.statusCode == 401 || response.statusCode == 403) {
      _logDebug('Refresh token rejected (${response.statusCode}), clearing tokens');
      await _tokenService.clearTokens();
      return false;
    }

    // For other non-200 responses
    _logError('Token refresh failed with status ${response.statusCode}: ${response.body}');
    return false;
  } on TimeoutException catch (e, st) {
    _logError('Token refresh timed out', e, st);
    return false;
  } catch (e, st) {
    _logError('Token refresh failed', e, st);
    return false;
  } finally {
    try {
      _refreshCompleter?.complete();
    } catch (_) {}
    _refreshCompleter = null;
    _isRefreshing = false;
  }
}

  void _logDebug(String message) {
    try {
      debugPrint('ApiService: DEBUG: $message');
    } catch (_) {
      print('ApiService: DEBUG: $message');
    }
  }

  void _logError(String message, [Object? error, StackTrace? st]) {
    try {
      debugPrint('ApiService: ERROR: $message ${error ?? ''}');
      if (st != null) debugPrint(st.toString());
    } catch (_) {
      print('ApiService: ERROR: $message ${error ?? ''}');
    }
  }

  // Updated getHeaders to use TokenService
  Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _tokenService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Public POST method (no authentication required)
 Future<dynamic> postPublic(String endpoint, dynamic data) async {
  try {
    _logDebug('API POST (Public): $baseUrl/$endpoint');
    _logDebug('API Data type: ${data.runtimeType}');
    _logDebug('API Data: $data');
    
    // Make sure data is properly encoded
    String jsonBody;
    if (data is Map || data is List) {
      jsonBody = json.encode(data);
    } else if (data is String) {
      // If data is already a string, check if it's valid JSON
      try {
        json.decode(data); // Validate it's JSON
        jsonBody = data;
      } catch (e) {
        // If not JSON, wrap it as JSON string
        jsonBody = json.encode({'data': data});
      }
    } else {
      // For other types, convert to JSON
      jsonBody = json.encode(data);
    }
    
    _logDebug('JSON Body being sent: $jsonBody');
    
    final response = await client.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonBody,
    ).timeout(const Duration(seconds: 30));
    
    return await _handlePublicResponse(response);
  } catch (e) {
    _logError('API POST (Public) Error', e);
    rethrow;
  }
}


Future<dynamic> googleAuth(Map<String, dynamic> authData) async {
  try {
    final endpoint = 'users/auth/google/';
    _logDebug('Google Auth: $baseUrl/$endpoint');
    
    // Log Google auth attempt
    _errorLogger?.logAuthInfo(
      'Google authentication attempt',
      metadata: {
        'endpoint': endpoint,
        'user_type': authData['user_type'],
        'has_phone': authData.containsKey('phone'),
      },
    );
    
    // Create request body with REQUIRED fields
    final requestBody = {
      'access_token': authData['access_token']?.toString() ?? '',
      'user_type': authData['user_type'] ?? 'customer',
    };
    
    // Add id_token if present (REQUIRED by backend)
    if (authData.containsKey('id_token') && authData['id_token'] != null) {
      requestBody['id_token'] = authData['id_token']!.toString();
    }
    
    // Add optional fields for registration
    if (authData.containsKey('phone') && authData['phone'] != null) {
      requestBody['phone'] = authData['phone']!.toString();
    }
    if (authData.containsKey('username') && authData['username'] != null) {
      requestBody['username'] = authData['username']!.toString();
    }
    if (authData.containsKey('first_name') && authData['first_name'] != null) {
      requestBody['first_name'] = authData['first_name']!.toString();
    }
    if (authData.containsKey('last_name') && authData['last_name'] != null) {
      requestBody['last_name'] = authData['last_name']!.toString();
    }
    if (authData.containsKey('email') && authData['email'] != null) {
      requestBody['email'] = authData['email']!.toString();
    }
    
    // Restaurant fields
    if (authData.containsKey('restaurant_name') && authData['restaurant_name'] != null) {
      requestBody['restaurant_name'] = authData['restaurant_name']!.toString();
    }
    if (authData.containsKey('business_license') && authData['business_license'] != null) {
      requestBody['business_license'] = authData['business_license']!.toString();
    }
    if (authData.containsKey('address') && authData['address'] != null) {
      requestBody['address'] = authData['address']!.toString();
    }
    
    // Driver fields
    if (authData.containsKey('license_number') && authData['license_number'] != null) {
      requestBody['license_number'] = authData['license_number']!.toString();
    }
    if (authData.containsKey('vehicle_type') && authData['vehicle_type'] != null) {
      requestBody['vehicle_type'] = authData['vehicle_type']!.toString();
    }
    
    _logDebug('Request Body: $requestBody');
    _logDebug('Request Body Keys: ${requestBody.keys.toList()}');
    
    final requestBodyJson = json.encode(requestBody);
    
    final response = await client.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: requestBodyJson,
    ).timeout(const Duration(seconds: 30));
    
    // Log successful response
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _errorLogger?.logAuthInfo(
        'Google auth backend response received',
        metadata: {
          'status_code': response.statusCode,
          'response_length': response.body.length,
        },
      );
    }
    
    return await _handlePublicResponse(response, endpoint: endpoint, requestBody: requestBodyJson);
  } catch (e, stackTrace) {
    _logError('Google Auth Error', e);
    _errorLogger?.logBackendError(
      message: 'Google authentication backend error',
      endpoint: 'users/auth/google/',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}


// GET method
Future<dynamic> get(String endpoint, {Map<String, String>? params}) async {
  return await _sendRequest(() async {
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: params);
    print('API GET: $uri');
    return await client.get(uri, headers: await getHeaders());
  }, endpoint: endpoint);
}

// POST method
Future<dynamic> post(String endpoint, dynamic data) async {
  return await _sendRequest(() async {
    print('API POST: $baseUrl/$endpoint');
    print('API Data: $data');
    
    return await client.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: await getHeaders(),
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
  }, endpoint: endpoint);
}

// PUT method
Future<dynamic> put(String endpoint, dynamic data) async {
  return await _sendRequest(() async {
    print('API PUT: $baseUrl/$endpoint');
    print('API Data: $data');
    
    return await client.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: await getHeaders(),
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
  }, endpoint: endpoint);
}

// PATCH method
Future<dynamic> patch(String endpoint, dynamic data) async {
  return await _sendRequest(() async {
    return await client.patch(
      Uri.parse('$baseUrl/$endpoint'),
      headers: await getHeaders(),
      body: json.encode(data),
    ).timeout(const Duration(seconds: 30));
  }, endpoint: endpoint);
}

// DELETE method
// DELETE method - UPDATED to accept data
Future<dynamic> delete(String endpoint, {Map<String, dynamic>? data}) async {
  return await _sendRequest(() async {
    print('API DELETE: $baseUrl/$endpoint');
    
    if (data != null) {
      // For DELETE with body, you need to use a Request
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      
      final request = http.Request('DELETE', Uri.parse('$baseUrl/$endpoint'))
        ..headers.addAll(headers)
        ..body = json.encode(data);
      
      final streamedResponse = await client.send(request);
      return http.Response.fromStream(streamedResponse);
    } else {
      return await client.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 30));
    }
  });
}

 
  // Response handler for public requests (no authentication)
  Future<dynamic> _handlePublicResponse(http.Response response, {String? endpoint, String? requestBody}) async {
    _logDebug('Public API Response - Status: ${response.statusCode}, URL: ${response.request?.url}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      
      try {
        final decodedResponse = json.decode(response.body);
        _logDebug('Public API Success Response Type: ${decodedResponse.runtimeType}');
        return decodedResponse;
      } catch (e) {
        _logError('JSON Parse Error', e);
        throw Exception('Failed to parse response: $e');
      }
    } else {
      _logDebug('Public API Error - Status: ${response.statusCode}, Body: ${response.body}');
      
      // Log detailed backend error
      _errorLogger?.logBackendError(
        message: 'Backend returned error response',
        endpoint: endpoint ?? response.request?.url.toString(),
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
      );
      
      try {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? error['message'] ?? error['error'] ?? 'Something went wrong');
      } catch (e) {
        throw Exception('Something went wrong (Status: ${response.statusCode})');
      }
    }
  }

  

  // Helper method to check authentication status
  Future<bool> isAuthenticated() async {
    final token = await _tokenService.getAccessToken();
    if (token == null) return false;
    
    final isExpired = await _tokenService.isAccessTokenExpired();
    return !isExpired;
  }

  // Method to clear all tokens and user data
  Future<void> logout() async {
    await _tokenService.clearTokens();
    _logDebug('User logged out, tokens cleared');
  }
}