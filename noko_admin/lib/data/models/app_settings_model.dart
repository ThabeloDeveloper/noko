import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final double deliveryFee;

  const AppSettingsModel({required this.deliveryFee});

  factory AppSettingsModel.defaults() {
    return const AppSettingsModel(deliveryFee: 15);
  }

  Map<String, dynamic> toMap() {
    return {
      'deliveryFee': deliveryFee,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppSettingsModel(deliveryFee: _toDouble(data['deliveryFee'], 15));
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }
}
