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
  final String fulfillmentType; // 'delivery' or 'collection'
  final String collectionType; // 'take_away' or 'eat_in'
  final String
  status; // 'pending', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final String paymentStatus; // 'pending', 'paid', 'failed', 'completed'
  final String paymentMethod; // 'cash_on_delivery' or gateway identifier
  final String verificationCode;
  final String? promoCode;
  final String restaurantNote;
  final double discount;
  final int etaMinutes;
  final double? routeDistanceMeters;
  final int? routeDurationSeconds;
  final String? routeProvider;
  final List<Map<String, dynamic>> routePolyline;
  final String? peachCheckoutId;
  final bool manualRefundRequired;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.restaurantId,
    this.driverId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.fulfillmentType = 'delivery',
    this.collectionType = '',
    required this.status,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.driverLatitude,
    this.driverLongitude,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.verificationCode,
    this.promoCode,
    this.restaurantNote = '',
    this.discount = 0,
    this.etaMinutes = 45,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.routeProvider,
    this.routePolyline = const [],
    this.peachCheckoutId,
    this.manualRefundRequired = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'customerId': customerId,
      'restaurantId': restaurantId,
      'driverId': driverId,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'fulfillmentType': fulfillmentType,
      'collectionType': collectionType,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'driverLatitude': driverLatitude,
      'driverLongitude': driverLongitude,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'verificationCode': verificationCode,
      'promoCode': promoCode,
      'restaurantNote': restaurantNote,
      'discount': discount,
      'etaMinutes': etaMinutes,
      'routeDistanceMeters': routeDistanceMeters,
      'routeDurationSeconds': routeDurationSeconds,
      'routeProvider': routeProvider,
      'routePolyline': routePolyline,
      'peachCheckoutId': peachCheckoutId,
      'manualRefundRequired': manualRefundRequired,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toQrPayload() {
    return {'orderId': id, 'verificationCode': verificationCode};
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    final driverPoint = map['driverLocation'];
    return OrderModel(
      id: documentId,
      orderNumber: map['orderNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      driverId: map['driverId'],
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      fulfillmentType: map['fulfillmentType'] ?? 'delivery',
      collectionType: map['collectionType'] ?? '',
      status: map['status'] ?? 'pending',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryLatitude: _toDouble(map['deliveryLatitude']),
      deliveryLongitude: _toDouble(map['deliveryLongitude']),
      driverLatitude:
          _toDouble(map['driverLatitude']) ??
          (driverPoint is GeoPoint ? driverPoint.latitude : null),
      driverLongitude:
          _toDouble(map['driverLongitude']) ??
          (driverPoint is GeoPoint ? driverPoint.longitude : null),
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'cash_on_delivery',
      verificationCode: map['verificationCode'] ?? '',
      promoCode: map['promoCode'],
      restaurantNote: map['restaurantNote'] ?? '',
      discount: (map['discount'] ?? 0.0).toDouble(),
      etaMinutes: (map['etaMinutes'] ?? 45).toInt(),
      routeDistanceMeters: _toDouble(map['routeDistanceMeters']),
      routeDurationSeconds: map['routeDurationSeconds'] is num
          ? (map['routeDurationSeconds'] as num).toInt()
          : null,
      routeProvider: map['routeProvider'],
      routePolyline: List<Map<String, dynamic>>.from(
        (map['routePolyline'] as List? ?? []).whereType<Map>(),
      ),
      peachCheckoutId: map['peachCheckoutId'],
      manualRefundRequired: map['manualRefundRequired'] == true,
      createdAt: _dateFromTimestamp(map['createdAt']),
      updatedAt: _dateFromTimestamp(map['updatedAt']),
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel.fromMap(data, doc.id);
  }

  static DateTime _dateFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.now();
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
