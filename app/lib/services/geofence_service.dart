class GeofenceService {
  // VIT Vellore Campus Bounds
  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;

  GeofenceService({
    this.latMin = 12.9640,
    this.latMax = 12.9785,
    this.lngMin = 79.1510,
    this.lngMax = 79.1675,
  });

  bool isInsideCampus(double latitude, double longitude) {
    return latitude >= latMin &&
        latitude <= latMax &&
        longitude >= lngMin &&
        longitude <= lngMax;
  }
}
