import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;

  const AddressModel({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AddressModel copyWith({
    String? id,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AddressModel.fromDynamic(dynamic value) {
    if (value is String) {
      return AddressModel(
        id: _idFromAddress(value),
        label: 'Saved address',
        address: value,
        createdAt: DateTime.now(),
      );
    }

    final map = Map<String, dynamic>.from(value as Map);
    final address = (map['address'] ?? '').toString();
    return AddressModel(
      id: (map['id'] ?? _idFromAddress(address)).toString(),
      label: (map['label'] ?? 'Saved address').toString(),
      address: address,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      isDefault: map['isDefault'] == true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  static String _idFromAddress(String address) {
    return address.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
