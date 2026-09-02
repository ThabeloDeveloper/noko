import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isOpen;

  const Restaurant({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.isOpen,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final point = data['geoPoint'] ?? data['locationPoint'];
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? data['location'] ?? '',
      latitude:
          _toDouble(data['latitude']) ??
          (point is GeoPoint ? point.latitude : null),
      longitude:
          _toDouble(data['longitude']) ??
          (point is GeoPoint ? point.longitude : null),
      isOpen: data['isOpen'] ?? false,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }
}
