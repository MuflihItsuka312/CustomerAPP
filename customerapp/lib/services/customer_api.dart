import 'dart:convert';
import 'package:http/http.dart' as http;

class CustomerApi {
  final String baseUrl;
  String? _token; // JWT setelah login

  CustomerApi({required this.baseUrl});

  set token(String? t) => _token = t;

  Map<String, String> _headers({bool withAuth = false}) {
    final h = {
      'Content-Type': 'application/json',
    };
    if (withAuth && _token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  // REGISTER
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );
    return jsonDecode(resp.body);
  }

  // LOGIN
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final resp = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(resp.body);
    if (resp.statusCode == 200 && data['token'] != null) {
      _token = data['token'];
    }
    return data;
  }

  // LIST PAKET CUSTOMER
  Future<List<dynamic>> getMyShipments() async {
    final url = Uri.parse('$baseUrl/api/customer/shipments');
    final resp = await http.get(
      url,
      headers: _headers(withAuth: true),
    );

    final data = jsonDecode(resp.body);
    return data['data'] ?? [];
  }

  // INPUT RESI MANUAL (auto-cek Binderbyte)
  Future<Map<String, dynamic>> addManualResi(String resi) async {
    final url = Uri.parse('$baseUrl/api/customer/manual-resi');
    final resp = await http.post(
      url,
      headers: _headers(withAuth: true),
      body: jsonEncode({'resi': resi}),
    );
    return jsonDecode(resp.body);
  }

  // MINTA BUKA LOKER untuk resi tertentu
  Future<Map<String, dynamic>> openLocker({
    required String resi,
    required String courierType,
  }) async {
    final url = Uri.parse('$baseUrl/api/customer/open-locker');
    final resp = await http.post(
      url,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'resi': resi,
        'courierType': courierType,
      }),
    );
    return jsonDecode(resp.body);
  }

  // DETAIL TRACKING (gabungan internal + Binderbyte)
  Future<Map<String, dynamic>> trackResi({
    required String resi,
    required String courier,
  }) async {
    final url = Uri.parse('$baseUrl/api/customer/track/$resi?courier=$courier');
    final resp = await http.get(
      url,
      headers: _headers(withAuth: false), // kalau mau bisa tanpa auth
    );
    return jsonDecode(resp.body);
  }
}
