import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'geofence_service.dart';

class LocationTrackerService {
  final String backendUrl;
  final GeofenceService geofenceService;
  final String riderId;

  bool _isTracking = false;
  bool _isOnShuttle = false;
  String? _routeHint;
  Timer? _timer;

  // Current simulated/device location state
  double _currentLat = 12.97120;
  double _currentLng = 79.15850;
  double _speedMps = 0.0;
  double _heading = 75.0;

  LocationTrackerService({
    this.backendUrl = 'http://127.0.0.1:8000',
    GeofenceService? geofenceService,
    required this.riderId,
  }) : geofenceService = geofenceService ?? GeofenceService();

  bool get isTracking => _isTracking;
  bool get isOnShuttle => _isOnShuttle;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;

  void startTracking({required bool isOnShuttle, String? routeHint}) {
    _isTracking = true;
    _isOnShuttle = isOnShuttle;
    _routeHint = routeHint;
    _scheduleNextPing();
  }

  void updatePosition({
    required double lat,
    required double lng,
    required double speedMps,
    required double heading,
  }) {
    _currentLat = lat;
    _currentLng = lng;
    _speedMps = speedMps;
    _heading = heading;

    // Reschedule ping rate based on velocity
    if (_isTracking) {
      _scheduleNextPing();
    }
  }

  void _scheduleNextPing() {
    _timer?.cancel();
    if (!_isTracking) return;

    // 1. Geofence Check: Stop/pause tracking if outside campus
    if (!geofenceService.isInsideCampus(_currentLat, _currentLng)) {
      // Outside VIT Campus: pause tracking
      return;
    }

    // 2. Adaptive GPS Sampling Rate:
    // Low sampling when stationary (< 1.2 m/s): 15 seconds to save battery
    // High sampling when in motion (> 1.2 m/s): 2 seconds for high fidelity clustering
    final durationSec = (_speedMps < 1.2) ? 15 : 2;

    _timer = Timer(Duration(seconds: durationSec), () {
      _sendPing();
      _scheduleNextPing();
    });
  }

  Future<void> _sendPing() async {
    if (!_isTracking) return;
    try {
      final payload = {
        'rider_id': riderId,
        'latitude': _currentLat,
        'longitude': _currentLng,
        'speed_mps': _speedMps,
        'heading': _heading,
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
        'is_on_shuttle': _isOnShuttle,
        'route_hint': _routeHint,
      };

      await http.post(
        Uri.parse('$backendUrl/api/v1/ping'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
    } catch (e) {
      // Ignored for network resilience
    }
  }

  void stopTracking() {
    _isTracking = false;
    _isOnShuttle = false;
    _timer?.cancel();
  }
}
