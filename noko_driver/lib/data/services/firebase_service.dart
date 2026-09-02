import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noko_driver/data/models/driver_message.dart';
import 'package:noko_driver/data/models/driver_order.dart';
import 'package:noko_driver/data/models/restaurant.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriver(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateDriverAvailability({
    required String uid,
    required bool online,
  }) async {
    await _db.collection('users').doc(uid).set({
      'driverOnline': online,
      'driverStatus': online ? 'available' : 'offline',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMessagingToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<DriverOrder>> watchAssignedOrders(String driverId) {
    return _db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => DriverOrder.fromFirestore(doc))
              .where((order) => order.isReadyForDriver)
              .toList();
          orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return orders;
        });
  }

  Stream<List<DriverOrder>> watchDeliveryHistory(String driverId) {
    return _db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => DriverOrder.fromFirestore(doc))
              .where(
                (order) =>
                    order.isDelivery &&
                    ['delivered', 'failed_delivery'].contains(order.status),
              )
              .toList();
          orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return orders;
        });
  }

  Stream<DriverOrder?> watchOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DriverOrder.fromFirestore(doc);
    });
  }

  Future<Restaurant?> getRestaurant(String restaurantId) async {
    final doc = await _db.collection('restaurants').doc(restaurantId).get();
    if (!doc.exists) return null;
    return Restaurant.fromFirestore(doc);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  Future<void> markDelivered(String orderId) async {
    await _functions.httpsCallable('updateDriverOrderStatus').call({
      'orderId': orderId,
      'status': 'delivered',
    });
  }

  Future<void> failDelivery({
    required String orderId,
    required String reason,
  }) async {
    await _functions.httpsCallable('failDriverDelivery').call({
      'orderId': orderId,
      'reason': reason,
    });
  }

  Future<void> settleOrder({
    required String qrPayload,
    required String driverId,
    String? expectedOrderId,
  }) async {
    final payload = _decodePayload(qrPayload);
    final orderId = payload['orderId'];
    final verificationCode = payload['verificationCode'];

    if (orderId == null || verificationCode == null) {
      throw const FormatException('Invalid order QR code.');
    }
    if (expectedOrderId != null && expectedOrderId != orderId) {
      throw const FormatException('This QR code belongs to another order.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'settleOrderDelivery',
    );
    await callable.call({
      'orderId': orderId,
      'verificationCode': verificationCode,
      'driverId': driverId,
    });
  }

  Future<Position> ensureLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Turn on location services to share live delivery.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for live tracking.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    await _functions.httpsCallable('updateDriverLocation').call({
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Stream<Position> locationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    );
  }

  Stream<List<DriverMessage>> watchMessages(String userId, String otherId) {
    return _db
        .collection('messages')
        .where(
          Filter.or(
            Filter.and(
              Filter('senderId', isEqualTo: userId),
              Filter('receiverId', isEqualTo: otherId),
            ),
            Filter.and(
              Filter('senderId', isEqualTo: otherId),
              Filter('receiverId', isEqualTo: userId),
            ),
          ),
        )
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => DriverMessage.fromFirestore(doc))
              .toList();
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  Future<void> sendMessage(DriverMessage message) async {
    await _db.collection('messages').add(message.toMap());
  }

  Future<void> markMessagesRead({
    required String userId,
    required String otherId,
  }) async {
    final unread = await _db
        .collection('messages')
        .where('senderId', isEqualTo: otherId)
        .where('receiverId', isEqualTo: userId)
        .where('readAt', isNull: true)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  double deliveryEarnings(List<DriverOrder> orders) {
    return orders
        .where((order) => order.status == 'delivered')
        .fold<double>(0, (total, order) => total + order.deliveryFee);
  }

  Map<String, dynamic> _decodePayload(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid order QR code.');
    }
    return decoded;
  }
}
