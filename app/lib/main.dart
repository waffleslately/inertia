import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/colors.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/location_tracker_service.dart';
import 'providers/shuttle_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/spend_provider.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const backendHost = '127.0.0.1:8000';
  final apiService = ApiService(baseUrl: 'http://$backendHost');
  final wsService = WebSocketService(wsUrl: 'ws://$backendHost/ws/shuttles');
  final locationTracker = LocationTrackerService(
    backendUrl: 'http://$backendHost',
    riderId: 'demo_rider',
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<WebSocketService>.value(value: wsService),
        Provider<LocationTrackerService>.value(value: locationTracker),
        ChangeNotifierProvider(
          create: (_) => ShuttleProvider(
            apiService: apiService,
            wsService: wsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RideProvider(
            apiService: apiService,
            locationTracker: locationTracker,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SpendProvider(
            apiService: apiService,
            riderId: 'demo_rider',
          ),
        ),
      ],
      child: const InertiaApp(),
    ),
  );
}

class InertiaApp extends StatelessWidget {
  const InertiaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inertia — VIT Shuttle Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.electricCyan,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.electricCyan,
          secondary: AppColors.electricBlue,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MainShellScreen(),
    );
  }
}
