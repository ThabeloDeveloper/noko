import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModel {
  final String id;
  final String code;
  final String type;
  final double value;
  final double minSubtotal;
  final bool active;
  final DateTime? expiresAt;

  const PromoCodeModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.minSubtotal,
    required this.active,
    required this.expiresAt,
  });

  double discountFor(double subtotal) {
    if (!active || subtotal < minSubtotal) {
      return 0;
    }
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) {
      return 0;
    }
    if (type == 'percent') {
      return subtotal * (value.clamp(0, 100) / 100);
    }
    return value.clamp(0, subtotal);
  }

  factory PromoCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PromoCodeModel(
      id: doc.id,
      code: (data['code'] ?? doc.id).toString().toUpperCase(),
      type: data['type'] ?? 'fixed',
      value: (data['value'] ?? 0).toDouble(),
      minSubtotal: (data['minSubtotal'] ?? 0).toDouble(),
      active: data['active'] ?? false,
      expiresAt: data['expiresAt'] is Timestamp
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }
}
