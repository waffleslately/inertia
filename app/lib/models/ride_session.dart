class RideSessionModel {
  final String sessionId;
  final String riderId;
  final String routeId;
  final String status;
  final String message;

  RideSessionModel({
    required this.sessionId,
    required this.riderId,
    required this.routeId,
    required this.status,
    required this.message,
  });

  factory RideSessionModel.fromJson(Map<String, dynamic> json) {
    return RideSessionModel(
      sessionId: json['session_id'] ?? '',
      riderId: json['rider_id'] ?? '',
      routeId: json['route_id'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      message: json['message'] ?? '',
    );
  }
}

class RideHistoryItemModel {
  final String sessionId;
  final String riderId;
  final String routeId;
  final String routeName;
  final double startTime;
  final double? endTime;
  final String status;
  final double fare;
  final bool paid;

  RideHistoryItemModel({
    required this.sessionId,
    required this.riderId,
    required this.routeId,
    required this.routeName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.fare,
    required this.paid,
  });

  factory RideHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return RideHistoryItemModel(
      sessionId: json['session_id'] ?? '',
      riderId: json['rider_id'] ?? '',
      routeId: json['route_id'] ?? '',
      routeName: json['route_name'] ?? 'VIT Campus Shuttle',
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble(),
      status: json['status'] ?? 'COMPLETED',
      fare: (json['fare'] as num?)?.toDouble() ?? 20.0,
      paid: json['paid'] == true || json['paid'] == 1,
    );
  }

  String get durationDisplay {
    if (endTime == null) return 'In Progress';
    final durationSec = (endTime! - startTime).toInt();
    final mins = (durationSec / 60).round();
    return '$mins min';
  }
}
