class ShuttleModel {
  final String shuttleId;
  final String routeId;
  final double latitude;
  final double longitude;
  final double snappedLat;
  final double snappedLng;
  final double speedKmh;
  final double bearing;
  final int riderCount;
  final String crowdCategory;
  final double crowdRatio;
  final String? nextStopId;
  final String? nextStopName;
  final int? etaSeconds;
  final double lastUpdated;

  ShuttleModel({
    required this.shuttleId,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.snappedLat,
    required this.snappedLng,
    required this.speedKmh,
    required this.bearing,
    required this.riderCount,
    required this.crowdCategory,
    required this.crowdRatio,
    this.nextStopId,
    this.nextStopName,
    this.etaSeconds,
    required this.lastUpdated,
  });

  factory ShuttleModel.fromJson(Map<String, dynamic> json) {
    return ShuttleModel(
      shuttleId: json['shuttle_id'] ?? '',
      routeId: json['route_id'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      snappedLat: (json['snapped_lat'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble() ?? 0.0,
      snappedLng: (json['snapped_lng'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
      riderCount: json['rider_count'] ?? 1,
      crowdCategory: json['crowd_category'] ?? 'Low',
      crowdRatio: (json['crowd_ratio'] as num?)?.toDouble() ?? 0.3,
      nextStopId: json['next_stop_id'],
      nextStopName: json['next_stop_name'],
      etaSeconds: json['eta_seconds'],
      lastUpdated: (json['last_updated'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get etaDisplay {
    if (etaSeconds == null) return 'At Stop';
    if (etaSeconds! < 45) return 'Arriving';
    final mins = (etaSeconds! / 60).ceil();
    return '$mins min';
  }
}
