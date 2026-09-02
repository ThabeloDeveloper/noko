import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String location; // Or GeoPoint if using Firestore GeoPoint
  final String imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isOpen;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
    required this.imageUrl,
    this.latitude,
    this.longitude,
    required this.isOpen,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'location': location,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'isOpen': isOpen,
    };
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> map, String documentId) {
    final geoPoint = map['geoPoint'] ?? map['locationPoint'];
    return RestaurantModel(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      location: map['location'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude:
          _toDouble(map['latitude']) ??
          (geoPoint is GeoPoint ? geoPoint.latitude : null),
      longitude:
          _toDouble(map['longitude']) ??
          (geoPoint is GeoPoint ? geoPoint.longitude : null),
      isOpen: map['isOpen'] ?? false,
    );
  }

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RestaurantModel.fromMap(data, doc.id);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
