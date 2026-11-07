import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String defaultBaseUrl = 'https://the-menu-admin.onrender.com/api/driver-app-api';
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> _authHeaders(String token) => {
        ..._headers,
        'Authorization': 'Bearer $token',
      };

  /// Initialize configured base URL from storage
  static Future<void> initBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('driver_api_base_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _baseUrl = savedUrl.trim();
        if (kDebugMode) print('Loaded custom API base URL: $_baseUrl');
      }
    } catch (_) {}
  }

  /// Update base URL (useful for connecting to local the-menu-admin or staging)
  static Future<void> setBaseUrl(String newUrl) async {
    _baseUrl = newUrl.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_api_base_url', _baseUrl);
      if (kDebugMode) print('Saved new API base URL: $_baseUrl');
    } catch (_) {}
  }

  /// Test connectivity to the specified the-menu-admin endpoint
  static Future<bool> testServerConnection(String testUrl) async {
    try {
      final uri = Uri.parse(testUrl.endsWith('/') ? testUrl.substring(0, testUrl.length - 1) : testUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // --- Register ---
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String vehicleType,
    required String vehicleNumber,
  }) async {
    try {
      if (kDebugMode) print('DEBUG: Attempting register at $baseUrl/register');
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'vehicle_type': vehicleType,
          'vehicle_number': vehicleNumber,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print('DEBUG: Register error: $e');
      rethrow;
    }
  }

  // --- Login ---
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) print('DEBUG: Attempting login at $baseUrl/login');
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print('DEBUG: Login error: $e');
      rethrow;
    }
  }

  // --- Logout ---
  Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: _authHeaders(token),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print('DEBUG: Logout error: $e');
      return {'success': false, 'message': 'Logout failed'};
    }
  }

  // --- Get current user ---
  Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: _authHeaders(token),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handleResponse(response);
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/user'),
        headers: _authHeaders(token),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handleResponse(response);
      }
    } catch (_) {}

    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: _authHeaders(token),
    );
    return _handleResponse(response);
  }

  // --- Change Password (Authenticated) ---
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );
    return _handleResponse(response);
  }

  // --- Reset Password (Unauthenticated / Forgot Password) ---
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    return _handleResponse(response);
  }

  // --- Orders ---
  Future<Map<String, dynamic>> getOrders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders'),
      headers: _authHeaders(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getLatestOrders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders-latest'),
      headers: _authHeaders(token),
    );
    return _handleResponse(response);
  }

  /// Update order status with intelligent REST fallbacks (PATCH / POST)
  Future<Map<String, dynamic>> updateOrderStatus({
    required String token,
    required int orderId,
    required String status,
    String? reason,
    String? notes,
    String? photoBase64,
    String? recipientName,
  }) async {
    final body = jsonEncode({
      'status': status,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (photoBase64 != null && photoBase64.isNotEmpty) 'photo_base64': photoBase64,
      if (recipientName != null && recipientName.trim().isNotEmpty) 'recipient_name': recipientName.trim(),
    });

    // 1. Try PATCH /orders/{id}/status
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: _authHeaders(token),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handleResponse(response);
      }
      if (response.statusCode != 404 && response.statusCode != 405) {
        return _handleResponse(response);
      }
    } catch (_) {}

    // 2. Try POST /orders/{id}/status
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: _authHeaders(token),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _handleResponse(response);
      }
      if (response.statusCode != 404 && response.statusCode != 405) {
        return _handleResponse(response);
      }
    } catch (_) {}

    // 3. Try POST /orders/{id}/{status}
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/$status'),
        headers: _authHeaders(token),
        body: body,
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print('DEBUG: Error updating order status: $e');
      return {'success': false, 'message': 'Network error updating order status'};
    }
  }

  // --- Real-time Driver Telemetry to the-menu-admin ---
  Future<bool> sendDriverTelemetry({
    required String token,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    final payload = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading ?? 0.0,
      'speed': speed ?? 0.0,
      'accuracy': accuracy ?? 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 1. Try POST /driver/location
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/location'),
        headers: _authHeaders(token),
        body: payload,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}

    // 2. Try POST /driver/telemetry
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/telemetry'),
        headers: _authHeaders(token),
        body: payload,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  // --- Driver Shift Status Sync ---
  Future<void> updateDriverStatus({
    required String token,
    required int driverId,
    required String status,
  }) async {
    try {
      if (kDebugMode) print('DEBUG: Updating driver status to $status');
      final response = await http.post(
        Uri.parse('$baseUrl/driver/status'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'driver_id': driverId,
          'status': status,
        }),
      );
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('DEBUG: Failed to update status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('DEBUG: Error updating driver status: $e');
    }
  }

  // --- Response Handler ---
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('DEBUG: API Response (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, ...body};
    } else {
      return {
        'success': false,
        'message': body['message'] ?? 'Something went wrong',
        'errors': body['errors'],
      };
    }
  }
}
