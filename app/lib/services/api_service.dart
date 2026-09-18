import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route.dart';
import '../models/shuttle.dart';
import '../models/ride_session.dart';
import '../models/spend_summary.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000'});

  Future<List<RouteModel>> fetchRoutes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/routes'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final routesList = data['routes'] as List<dynamic>;
        return routesList.map((r) => RouteModel.fromJson(r)).toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<List<ShuttleModel>> fetchShuttles() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/shuttles'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        return data.map((s) => ShuttleModel.fromJson(s)).toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<RideSessionModel?> checkIn({
    required String riderId,
    String? routeId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/check-in'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'rider_id': riderId,
          'route_id': routeId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      if (res.statusCode == 200) {
        return RideSessionModel.fromJson(json.decode(res.body));
      }
    } catch (e) {
      // Return offline mock session if backend is initializing
      return RideSessionModel(
        sessionId: 'ride_offline_${DateTime.now().millisecondsSinceEpoch}',
        riderId: riderId,
        routeId: routeId ?? 'route_1',
        status: 'CHECKED_IN',
        message: 'Checked in (offline mode)',
      );
    }
    return null;
  }

  Future<bool> endRide({required String sessionId, required String riderId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/end-ride'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'session_id': sessionId, 'rider_id': riderId}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> recordPayment({
    String? sessionId,
    required String riderId,
    required String routeId,
    double amount = 20.0,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/payments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'rider_id': riderId,
          'route_id': routeId,
          'amount': amount,
          'status': 'COMPLETED',
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<RideHistoryItemModel>> fetchRideHistory(String riderId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/rides/history?rider_id=$riderId'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['rides'] as List<dynamic>;
        return list.map((r) => RideHistoryItemModel.fromJson(r)).toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<SpendSummaryModel?> fetchSpendSummary(String riderId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/spend/summary?rider_id=$riderId'));
      if (res.statusCode == 200) {
        return SpendSummaryModel.fromJson(json.decode(res.body));
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchConfig() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/config'));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }
}
