import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

/// Sayop gikan sa API o network. Ang message ipakita sa UI.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Usa ra ka wrapper para sa tanang REST calls. JWT ibutang dinhi.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Request timed out. Is the API running?');
    } catch (_) {
      throw ApiException('Cannot reach the API at ${AppConfig.apiBaseUrl}');
    }

    final text = response.body;
    final data = text.isEmpty ? null : _decode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      _errorMessage(data, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  /// FastAPI: {"detail": "..."} or validation list.
  String _errorMessage(dynamic data, int statusCode) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((item) => item is Map ? '${item['msg']}' : '$item')
            .join(', ');
      }
      return detail.toString();
    }
    if (statusCode == 401) return 'Session expired. Please log in again.';
    return 'Request failed (HTTP $statusCode)';
  }

  Map<String, dynamic> _map(dynamic data) => data as Map<String, dynamic>;

  // ---------- auth ----------
  Future<AuthResult> login(String email, String password) async {
    final data = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthResult.fromJson(_map(data));
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/register',
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
    return AuthResult.fromJson(_map(data));
  }

  Future<User> me() async {
    final data = await _send('GET', '/api/auth/me');
    return User.fromJson(_map(data));
  }

  // ---------- routes ----------
  Future<List<RouteInfo>> routes({String? search}) async {
    final data = await _send(
      'GET',
      '/api/routes',
      query: search == null || search.trim().isEmpty
          ? null
          : {'search': search.trim()},
    );
    return (data as List<dynamic>)
        .map((item) => RouteInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ---------- passenger queue ----------
  Future<QueueEntry> joinPassengerQueue(int routeId) async {
    final data = await _send(
      'POST',
      '/api/queue/passenger/join',
      body: {'route_id': routeId},
    );
    return QueueEntry.fromJson(_map(data));
  }

  Future<QueueEntry?> passengerQueue() async {
    final data = await _send('GET', '/api/queue/passenger');
    final entry = (data as Map<String, dynamic>)['entry'];
    return entry == null
        ? null
        : QueueEntry.fromJson(entry as Map<String, dynamic>);
  }

  Future<void> cancelPassengerQueue() async {
    await _send('DELETE', '/api/queue/passenger');
  }

  // ---------- driver queue ----------
  Future<QueueEntry> joinDriverQueue(int routeId) async {
    final data = await _send(
      'POST',
      '/api/queue/driver/join',
      body: {'route_id': routeId},
    );
    return QueueEntry.fromJson(_map(data));
  }

  Future<DriverQueueView> driverQueue() async {
    final data = await _send('GET', '/api/queue/driver');
    return DriverQueueView.fromJson(_map(data));
  }

  Future<QueueEntry> updateDriverStatus(int routeId, String status) async {
    // routeId wala gigamit sa API pero ato ibutang para klaro sa caller.
    assert(routeId > 0);
    final data = await _send(
      'PATCH',
      '/api/queue/driver/status',
      body: {'status': status},
    );
    return QueueEntry.fromJson(_map(data));
  }

  Future<void> leaveDriverQueue() async {
    await _send('DELETE', '/api/queue/driver');
  }

  Future<ServeResult> serveNextPassenger() async {
    final data = await _send('POST', '/api/queue/driver/serve');
    return ServeResult.fromJson(_map(data));
  }

  // ---------- admin ----------
  Future<List<DriverRecord>> drivers() async {
    final data = await _send('GET', '/api/admin/drivers');
    return (data as List<dynamic>)
        .map((item) => DriverRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DriverRecord> createDriver(Map<String, dynamic> body) async {
    final data = await _send('POST', '/api/admin/drivers', body: body);
    return DriverRecord.fromJson(_map(data));
  }

  Future<DriverRecord> updateDriver(
    int driverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _send(
      'PATCH',
      '/api/admin/drivers/$driverId',
      body: body,
    );
    return DriverRecord.fromJson(_map(data));
  }

  Future<void> deactivateDriver(int driverId) async {
    await _send('DELETE', '/api/admin/drivers/$driverId');
  }

  Future<List<RouteInfo>> adminRoutes() async {
    final data = await _send('GET', '/api/admin/routes');
    return (data as List<dynamic>)
        .map((item) => RouteInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RouteInfo> createRoute(String name) async {
    final data = await _send('POST', '/api/admin/routes', body: {'name': name});
    return RouteInfo.fromJson(_map(data));
  }

  Future<RouteInfo> updateRoute(
    int routeId, {
    String? name,
    bool? active,
  }) async {
    final data = await _send(
      'PATCH',
      '/api/admin/routes/$routeId',
      body: {
        'name': ?name,
        'active': ?active,
      },
    );
    return RouteInfo.fromJson(_map(data));
  }

  Future<void> disableRoute(int routeId) async {
    await _send('DELETE', '/api/admin/routes/$routeId');
  }

  Future<List<PublicRouteSummary>> adminQueues() async {
    final data = await _send('GET', '/api/admin/queues');
    return (data as List<dynamic>)
        .map((item) => PublicRouteSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminRouteQueue> adminRouteQueue(int routeId) async {
    final data = await _send('GET', '/api/admin/queues/$routeId');
    return AdminRouteQueue.fromJson(_map(data));
  }

  Future<void> closeQueueEntry(
    int entryId,
    String action,
    String reasonCode,
  ) async {
    await _send(
      'POST',
      '/api/admin/queue/$entryId/$action',
      body: {'reason_code': reasonCode},
    );
  }

  Future<DashboardStats> dashboard() async {
    final data = await _send('GET', '/api/admin/dashboard');
    return DashboardStats.fromJson(_map(data));
  }

  Future<List<Prediction>> predictions({int? routeId}) async {
    final data = await _send(
      'GET',
      '/api/admin/predictions',
      query: routeId == null ? null : {'route_id': '$routeId'},
    );
    return (data as List<dynamic>)
        .map((item) => Prediction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ---------- public (no login) ----------
  Future<List<PublicRouteSummary>> publicRoutes() async {
    final data = await _send('GET', '/api/public/routes');
    return (data as List<dynamic>)
        .map((item) => PublicRouteSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PublicRouteStatus> publicRouteStatus(int routeId) async {
    final data = await _send('GET', '/api/public/routes/$routeId/status');
    return PublicRouteStatus.fromJson(_map(data));
  }
}
