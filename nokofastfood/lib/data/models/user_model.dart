import 'package:cloud_firestore/cloud_firestore.dart';

import 'address_model.dart';

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String role; // 'customer' or 'driver'
  final List<AddressModel> savedAddresses;
  final List<String> favoriteProductIds;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.savedAddresses = const [],
    this.favoriteProductIds = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'savedAddresses': savedAddresses
          .map((address) => address.toMap())
          .toList(),
      'favoriteProductIds': favoriteProductIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      savedAddresses: (map['savedAddresses'] as List? ?? [])
          .map(AddressModel.fromDynamic)
          .toList(),
      favoriteProductIds: List<String>.from(map['favoriteProductIds'] ?? []),
      createdAt: _dateFromTimestamp(map['createdAt']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  static DateTime _dateFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.now();
  }
}
