import 'package:cloud_firestore/cloud_firestore.dart';

class DriverOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String restaurantId;
  final String? driverId;
  final List<Map<String, dynamic>> items;
  final double total;
  final double deliveryFee;
  final String fulfillmentType;
  final String status;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final String paymentMethod;
  final String paymentStatus;
  final String verificationCode;
  final int etaMinutes;
  final double? routeDistanceMeters;
  final int? routeDurationSeconds;
  final List<Map<String, dynamic>> routePolyline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.restaurantId,
    this.driverId,
    required this.items,
    required this.total,
    required this.deliveryFee,
    this.fulfillmentType = 'delivery',
    required this.status,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.driverLatitude,
    this.driverLongitude,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.verificationCode,
    required this.etaMinutes,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.routePolyline = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAssigned => driverId != null && driverId!.isNotEmpty;
  bool get isDelivery => fulfillmentType == 'delivery';
  bool get isReadyForDriver => isDelivery && status == 'out_for_delivery';
  bool get isActive =>
      isDelivery &&
      !['delivered', 'cancelled', 'failed_delivery'].contains(status);
  bool get canDeliver => isReadyForDriver;

  factory DriverOrder.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final driverPoint = data['driverLocation'];
    return DriverOrder(
      id: doc.id,
      orderNumber: data['orderNumber'] ?? '',
      customerId: data['customerId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      driverId: data['driverId'],
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      total: _toDouble(data['total']) ?? 0,
      deliveryFee: _toDouble(data['deliveryFee']) ?? 0,
      fulfillmentType: data['fulfillmentType'] ?? 'delivery',
      status: data['status'] ?? 'pending',
      deliveryAddress: data['deliveryAddress'] ?? '',
      deliveryLatitude: _toDouble(data['deliveryLatitude']),
      deliveryLongitude: _toDouble(data['deliveryLongitude']),
      driverLatitude:
          _toDouble(data['driverLatitude']) ??
          (driverPoint is GeoPoint ? driverPoint.latitude : null),
      driverLongitude:
          _toDouble(data['driverLongitude']) ??
          (driverPoint is GeoPoint ? driverPoint.longitude : null),
      paymentMethod: data['paymentMethod'] ?? 'cash_on_delivery',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      verificationCode: data['verificationCode'] ?? '',
      etaMinutes: (data['etaMinutes'] ?? 45).toInt(),
      routeDistanceMeters: _toDouble(data['routeDistanceMeters']),
      routeDurationSeconds: data['routeDurationSeconds'] is num
          ? (data['routeDurationSeconds'] as num).toInt()
          : null,
      routePolyline: (data['routePolyline'] as List? ?? [])
          .whereType<Map>()
          .map((point) => Map<String, dynamic>.from(point))
          .toList(),
      createdAt: _dateFromTimestamp(data['createdAt']),
      updatedAt: _dateFromTimestamp(data['updatedAt']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static DateTime _dateFromTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }
}
