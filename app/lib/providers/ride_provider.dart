import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ride_session.dart';
import '../services/api_service.dart';
import '../services/location_tracker_service.dart';

enum RideState {
  idle,            // "I'm on the shuttle"
  checkingIn,      // morphing / spinning
  activeRide,      // on shuttle tracking
  nearDestination, // arrival prompt triggered
  paymentSuccess,  // animated tick
}

class RideProvider extends ChangeNotifier {
  final ApiService apiService;
  final LocationTrackerService locationTracker;

  RideState _state = RideState.idle;
  RideSessionModel? _currentSession;
  String _activeRouteId = 'route_1';
  String _activeRouteName = 'Route 1: Main Loop';
  String _nextStop = 'Technology Tower (TT)';
  int _etaMinutes = 3;
  double _fare = 20.0;
  String _upiVpa = 'vitshuttle@okaxis';
  bool _showArrivalModal = false;

  RideProvider({
    required this.apiService,
    required this.locationTracker,
  }) {
    _loadConfig();
  }

  RideState get state => _state;
  RideSessionModel? get currentSession => _currentSession;
  String get activeRouteId => _activeRouteId;
  String get activeRouteName => _activeRouteName;
  String get nextStop => _nextStop;
  int get etaMinutes => _etaMinutes;
  double get fare => _fare;
  String get upiVpa => _upiVpa;
  bool get showArrivalModal => _showArrivalModal;

  Future<void> _loadConfig() async {
    final cfg = await apiService.fetchConfig();
    if (cfg != null) {
      _upiVpa = cfg['upi_vpa'] ?? _upiVpa;
      _fare = (cfg['shuttle_fare'] as num?)?.toDouble() ?? _fare;
      notifyListeners();
    }
  }

  Future<void> checkIn({String? routeId}) async {
    _state = RideState.checkingIn;
    notifyListeners();

    // Haptic feedback on button tap
    HapticFeedback.mediumImpact();

    final session = await apiService.checkIn(
      riderId: locationTracker.riderId,
      routeId: routeId ?? _activeRouteId,
      latitude: locationTracker.currentLat,
      longitude: locationTracker.currentLng,
    );

    if (session != null) {
      _currentSession = session;
      _activeRouteId = session.routeId;
      _activeRouteName = session.routeId == 'route_1'
          ? 'Route 1: Main Loop'
          : 'Route 2: Academic Express';
      _state = RideState.activeRide;

      // Start adaptive background location tracking
      locationTracker.startTracking(
        isOnShuttle: true,
        routeHint: _activeRouteId,
      );

      // Trigger success haptic
      HapticFeedback.lightImpact();
    } else {
      _state = RideState.idle;
    }
    notifyListeners();
  }

  void triggerArrivalAlert({String? destinationName}) {
    if (_state != RideState.activeRide) return;
    _state = RideState.nearDestination;
    _showArrivalModal = true;
    if (destinationName != null) {
      _nextStop = destinationName;
    }

    // Heavy haptic feedback on approaching stop arrival
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  void dismissArrivalModal() {
    _showArrivalModal = false;
    notifyListeners();
  }

  Future<void> launchUpiPayment({BuildContext? context}) async {
    // Generate UPI deep link formatted for Indian payment apps
    // upi://pay?pa=vitshuttle@okaxis&pn=VIT%20Shuttle&am=20.00&cu=INR&tn=Inertia%20Shuttle%20Ride
    final upiUrlString =
        'upi://pay?pa=$_upiVpa&pn=VIT%20Campus%20Shuttle&am=${_fare.toStringAsFixed(2)}&cu=INR&tn=Inertia%20Ride%20VIT%20Vellore';
    final uri = Uri.parse(upiUrlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // If UPI app not installed on desktop/simulator, fallback gracefully
    }

    // Record payment with backend
    await apiService.recordPayment(
      sessionId: _currentSession?.sessionId,
      riderId: locationTracker.riderId,
      routeId: _activeRouteId,
      amount: _fare,
    );

    _state = RideState.paymentSuccess;
    _showArrivalModal = false;
    notifyListeners();

    // Haptic confirmation
    HapticFeedback.selectionClick();

    // Stop tracking after ride finishes
    locationTracker.stopTracking();

    // Auto reset to idle after 4 seconds
    Timer(const Duration(seconds: 4), () {
      _state = RideState.idle;
      _currentSession = null;
      notifyListeners();
    });
  }

  Future<void> endRideManually() async {
    if (_currentSession != null) {
      await apiService.endRide(
        sessionId: _currentSession!.sessionId,
        riderId: locationTracker.riderId,
      );
    }
    locationTracker.stopTracking();
    _state = RideState.idle;
    _currentSession = null;
    _showArrivalModal = false;
    notifyListeners();
  }
}
