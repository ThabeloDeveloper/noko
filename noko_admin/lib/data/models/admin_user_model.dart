import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String fcmToken;
  final DateTime createdAt;

  const AdminUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.fcmToken,
    required this.createdAt,
  });

  factory AdminUserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdminUserModel(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      fcmToken: map['fcmToken'] ?? '',
      createdAt: _toDate(map['createdAt']),
    );
  }

  factory AdminUserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AdminUserModel.fromMap(data, doc.id);
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
