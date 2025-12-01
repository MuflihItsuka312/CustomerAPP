import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // ganti kalau backend-mu beda
  static const String baseUrl = 'https://serverr.shidou.cloud';

  static const String _tokenKey = 'auth_token';
  static const String _userNameKey = 'user_name';

  // ===== TOKEN STORAGE =====
  static Future<void> saveToken(String token, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userNameKey, name);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
  }

  // ===== HTTP HELPERS =====
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) {
      uri = uri.replace(queryParameters: query);
    }

    final headers = <String, String>{};
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return http.get(uri, headers: headers);
  }
}
