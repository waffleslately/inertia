class StopModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int sequence;

  StopModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      sequence: json['sequence'] ?? 0,
    );
  }
}

class RouteModel {
  final String id;
  final String name;
  final String shortName;
  final String colorHex;
  final double fare;
  final List<StopModel> stops;
  final List<List<double>> polyline;

  RouteModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorHex,
    required this.fare,
    required this.stops,
    required this.polyline,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      shortName: json['short_name'] ?? '',
      colorHex: json['color'] ?? '#00E5FF',
      fare: (json['fare'] as num?)?.toDouble() ?? 20.0,
      stops: (json['stops'] as List<dynamic>?)
              ?.map((s) => StopModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      polyline: (json['polyline'] as List<dynamic>?)
              ?.map((p) => [
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                  ])
              .toList() ??
          [],
    );
  }
}
