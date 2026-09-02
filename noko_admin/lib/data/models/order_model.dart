import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String restaurantId;
  final String? driverId;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String fulfillmentType;
  final String collectionType;
  final String status;
  final String deliveryAddress;
  final String restaurantNote;
  final String paymentStatus;
  final String paymentMethod;
  final double? routeDistanceMeters;
  final int? routeDurationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.restaurantId,
    required this.driverId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.fulfillmentType = 'delivery',
    this.collectionType = '',
    required this.status,
    required this.deliveryAddress,
    this.restaurantNote = '',
    required this.paymentStatus,
    required this.paymentMethod,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      orderNumber: map['orderNumber'] ?? documentId,
      customerId: map['customerId'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      driverId: map['driverId'],
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      subtotal: _toDouble(map['subtotal']),
      deliveryFee: _toDouble(map['deliveryFee']),
      total: _toDouble(map['total']),
      fulfillmentType: map['fulfillmentType'] ?? 'delivery',
      collectionType: map['collectionType'] ?? '',
      status: map['status'] ?? 'pending',
      deliveryAddress: map['deliveryAddress'] ?? '',
      restaurantNote: map['restaurantNote'] ?? '',
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'cash_on_delivery',
      routeDistanceMeters: _toNullableDouble(map['routeDistanceMeters']),
      routeDurationSeconds: map['routeDurationSeconds'] is num
          ? (map['routeDurationSeconds'] as num).toInt()
          : null,
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return OrderModel.fromMap(data, doc.id);
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
