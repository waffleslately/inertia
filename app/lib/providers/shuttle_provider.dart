import 'dart:async';
import 'package:flutter/material.dart';
import '../models/route.dart';
import '../models/shuttle.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class InterpolatedShuttle {
  final ShuttleModel model;
  final double currentLat;
  final double currentLng;
  final double targetLat;
  final double targetLng;
  final double startBearing;
  final double targetBearing;
  final DateTime updateTime;

  InterpolatedShuttle({
    required this.model,
    required this.currentLat,
    required this.currentLng,
    required this.targetLat,
    required this.targetLng,
    required this.startBearing,
    required this.targetBearing,
    required this.updateTime,
  });

  InterpolatedShuttle copyWithLerp(double progress) {
    final t = progress.clamp(0.0, 1.0);
    // Smooth ease-out interpolation
    final ease = 1.0 - (1.0 - t) * (1.0 - t);
    return InterpolatedShuttle(
      model: model,
      currentLat: currentLat + (targetLat - currentLat) * ease,
      currentLng: currentLng + (targetLng - currentLng) * ease,
      targetLat: targetLat,
      targetLng: targetLng,
      startBearing: startBearing,
      targetBearing: targetBearing,
      updateTime: updateTime,
    );
  }
}

class ShuttleProvider extends ChangeNotifier {
  final ApiService apiService;
  final WebSocketService wsService;

  List<RouteModel> _routes = [];
  Map<String, InterpolatedShuttle> _shuttleMap = {};
  String? _selectedShuttleId;
  bool _isLoading = true;
  StreamSubscription? _sub;
  Timer? _ticker;

  ShuttleProvider({
    required this.apiService,
    required this.wsService,
  }) {
    _init();
  }

  List<RouteModel> get routes => _routes;
  List<InterpolatedShuttle> get shuttles => _shuttleMap.values.toList();
  InterpolatedShuttle? get selectedShuttle =>
      _selectedShuttleId != null ? _shuttleMap[_selectedShuttleId] : null;
  bool get isLoading => _isLoading;

  void _init() async {
    await fetchRoutes();
    final initialList = await apiService.fetchShuttles();
    _handleNewShuttleList(initialList);
    _isLoading = false;
    notifyListeners();

    // Connect WebSocket
    wsService.connect();
    _sub = wsService.shuttleStream.listen((list) {
      _handleNewShuttleList(list);
    });

    // 60fps local animation ticker for smooth marker gliding & interpolation
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _advanceInterpolation();
    });
  }

  Future<void> fetchRoutes() async {
    _routes = await apiService.fetchRoutes();
    notifyListeners();
  }

  void _handleNewShuttleList(List<ShuttleModel> newModels) {
    final now = DateTime.now();
    final newMap = <String, InterpolatedShuttle>{};

    for (var s in newModels) {
      final existing = _shuttleMap[s.shuttleId];
      if (existing != null) {
        newMap[s.shuttleId] = InterpolatedShuttle(
          model: s,
          currentLat: existing.currentLat,
          currentLng: existing.currentLng,
          targetLat: s.snappedLat,
          targetLng: s.snappedLng,
          startBearing: existing.model.bearing,
          targetBearing: s.bearing,
          updateTime: now,
        );
      } else {
        newMap[s.shuttleId] = InterpolatedShuttle(
          model: s,
          currentLat: s.snappedLat,
          currentLng: s.snappedLng,
          targetLat: s.snappedLat,
          targetLng: s.snappedLng,
          startBearing: s.bearing,
          targetBearing: s.bearing,
          updateTime: now,
        );
      }
    }

    _shuttleMap = newMap;
    notifyListeners();
  }

  void _advanceInterpolation() {
    if (_shuttleMap.isEmpty) return;
    final now = DateTime.now();
    bool changed = false;

    _shuttleMap.forEach((key, item) {
      final elapsedMs = now.difference(item.updateTime).inMilliseconds;
      // Interpolate over 1500ms (matching the backend broadcast interval)
      final progress = elapsedMs / 1500.0;
      if (progress < 1.0) {
        _shuttleMap[key] = item.copyWithLerp(progress);
        changed = true;
      }
    });

    if (changed) {
      notifyListeners();
    }
  }

  void selectShuttle(String? shuttleId) {
    _selectedShuttleId = shuttleId;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
