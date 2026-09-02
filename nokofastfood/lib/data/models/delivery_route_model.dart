class DeliveryRouteModel {
  final double distanceMeters;
  final int durationSeconds;
  final String provider;
  final List<Map<String, double>> routePolyline;

  const DeliveryRouteModel({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.provider,
    required this.routePolyline,
  });

  int get etaMinutes => (durationSeconds / 60).clamp(5, 180).ceil();

  double get distanceKilometres => distanceMeters / 1000;

  factory DeliveryRouteModel.fromMap(Map<String, dynamic> map) {
    return DeliveryRouteModel(
      distanceMeters: _toDouble(map['distanceMeters']) ?? 0,
      durationSeconds: (map['durationSeconds'] ?? 0).toInt(),
      provider: map['provider'] ?? 'unknown',
      routePolyline: (map['routePolyline'] as List? ?? [])
          .whereType<Map>()
          .map(
            (point) => Map<String, double>.from({
              'latitude': _toDouble(point['latitude']) ?? 0,
              'longitude': _toDouble(point['longitude']) ?? 0,
            }),
          )
          .where((point) => point['latitude'] != 0 || point['longitude'] != 0)
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
