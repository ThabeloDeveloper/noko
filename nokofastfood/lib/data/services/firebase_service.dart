import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';

import '../models/address_model.dart';
import '../models/app_settings_model.dart';
import '../models/delivery_route_model.dart';
import '../models/menu_category_model.dart';
import '../models/message_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/promo_code_model.dart';
import '../models/restaurant_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<AppSettingsModel> watchAppSettings() {
    return _db.collection('appSettings').doc('platform').snapshots().map((doc) {
      if (!doc.exists) {
        return AppSettingsModel.defaults();
      }
      return AppSettingsModel.fromFirestore(doc);
    });
  }

  Future<AppSettingsModel> getAppSettings() async {
    final doc = await _db.collection('appSettings').doc('platform').get();
    if (!doc.exists) {
      return AppSettingsModel.defaults();
    }
    return AppSettingsModel.fromFirestore(doc);
  }

  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updateUserMessagingToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<AddressModel> buildAddress({
    required String label,
    required String address,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    var nextLatitude = latitude;
    var nextLongitude = longitude;
    if (nextLatitude == null || nextLongitude == null) {
      try {
        final locations = await Geocoding().locationFromAddress(address);
        if (locations.isNotEmpty) {
          nextLatitude = locations.first.latitude;
          nextLongitude = locations.first.longitude;
        }
      } catch (_) {
        nextLatitude = null;
        nextLongitude = null;
      }
    }

    return AddressModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label.trim().isEmpty ? 'Saved address' : label.trim(),
      address: address.trim(),
      latitude: nextLatitude,
      longitude: nextLongitude,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );
  }

  Future<void> saveAddress(String uid, AddressModel address) async {
    final user = await getUser(uid);
    final addresses = [...?user?.savedAddresses];
    final nextAddress = address.copyWith(
      isDefault: address.isDefault || addresses.isEmpty,
    );
    final nextAddresses = [
      for (final existing in addresses)
        if (existing.id != nextAddress.id)
          nextAddress.isDefault
              ? existing.copyWith(isDefault: false)
              : existing,
      nextAddress,
    ];

    await _db.collection('users').doc(uid).set({
      'savedAddresses': nextAddresses.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeAddress(String uid, AddressModel address) async {
    final user = await getUser(uid);
    final nextAddresses = [...?user?.savedAddresses]
        .where(
          (item) => item.id != address.id && item.address != address.address,
        )
        .toList();

    await _db.collection('users').doc(uid).set({
      'savedAddresses': nextAddresses.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDefaultAddress(String uid, AddressModel address) async {
    final user = await getUser(uid);
    final nextAddresses = [
      ...?user?.savedAddresses,
    ].map((item) => item.copyWith(isDefault: item.id == address.id)).toList();

    await _db.collection('users').doc(uid).set({
      'savedAddresses': nextAddresses.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleFavorite({
    required String uid,
    required String productId,
    required bool isFavorite,
  }) async {
    await _db.collection('users').doc(uid).set({
      'favoriteProductIds': isFavorite
          ? FieldValue.arrayRemove([productId])
          : FieldValue.arrayUnion([productId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<RestaurantModel>> getRestaurants() {
    return _db.collection('restaurants').snapshots().map((snapshot) {
      final restaurants = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .toList();
      restaurants.sort((a, b) => a.name.compareTo(b.name));
      return restaurants;
    });
  }

  Future<RestaurantModel?> getRestaurant(String id) async {
    final doc = await _db.collection('restaurants').doc(id).get();
    if (doc.exists) {
      return RestaurantModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<ProductModel>> getProducts([String? restaurantId]) {
    Query<Map<String, dynamic>> query = _db.collection('products');
    if (restaurantId != null && restaurantId.isNotEmpty) {
      query = query.where('restaurantId', isEqualTo: restaurantId);
    }
    return query.snapshots().map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    });
  }

  Stream<List<MenuCategoryModel>> getMenuCategories() {
    return _db.collection('menuCategories').snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => MenuCategoryModel.fromFirestore(doc))
          .where(
            (category) => category.active && category.name.trim().isNotEmpty,
          )
          .toList();
      categories.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
      return categories;
    });
  }

  Future<void> createOrder(OrderModel order) async {
    await _db.collection('orders').doc(order.id).set(order.toMap());
  }

  Future<DeliveryRouteModel> calculateDeliveryRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final result = await _functions
        .httpsCallable('calculateDeliveryRoute')
        .call({
          'originLatitude': originLatitude,
          'originLongitude': originLongitude,
          'destinationLatitude': destinationLatitude,
          'destinationLongitude': destinationLongitude,
        });
    return DeliveryRouteModel.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<OrderModel?> watchOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return OrderModel.fromFirestore(doc);
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await _functions.httpsCallable('cancelCustomerOrder').call({
      'orderId': orderId,
    });
  }

  Future<PromoCodeModel?> getPromoCode(String code) async {
    final normalised = code.trim().toUpperCase();
    if (normalised.isEmpty) {
      return null;
    }
    final direct = await _db.collection('promoCodes').doc(normalised).get();
    if (direct.exists) {
      return PromoCodeModel.fromFirestore(direct);
    }
    final query = await _db
        .collection('promoCodes')
        .where('code', isEqualTo: normalised)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }
    return PromoCodeModel.fromFirestore(query.docs.first);
  }

  Stream<List<PromoCodeModel>> getActivePromoCodes() {
    return _db
        .collection('promoCodes')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final promos = snapshot.docs
              .map((doc) => PromoCodeModel.fromFirestore(doc))
              .where(
                (promo) =>
                    promo.active &&
                    (promo.expiresAt == null ||
                        promo.expiresAt!.isAfter(DateTime.now())),
              )
              .toList();
          promos.sort((a, b) => a.code.compareTo(b.code));
          return promos;
        });
  }

  Stream<List<ReviewModel>> getProductReviews(String productId) {
    return _db
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map((doc) => ReviewModel.fromFirestore(doc))
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  Future<void> addReview(ReviewModel review) async {
    await _db.collection('reviews').add(review.toMap());
  }

  Future<bool> hasPurchasedProduct({
    required String uid,
    required String productId,
  }) async {
    final orders = await _db
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .get();
    return orders.docs.any((doc) {
      final items = List<Map<String, dynamic>>.from(doc.data()['items'] ?? []);
      return items.any((item) => item['productId'] == productId);
    });
  }

  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    await _db.collection('reviews').doc(reviewId).set({
      'rating': rating,
      'comment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReview(String reviewId) async {
    await _db.collection('reviews').doc(reviewId).delete();
  }

  Future<void> reportReview({
    required String reviewId,
    required String productId,
    required String reason,
    required String reporterId,
  }) async {
    await _db.collection('reviewReports').add({
      'reviewId': reviewId,
      'productId': productId,
      'reason': reason,
      'reporterId': reporterId,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<PeachCheckoutSession> createPeachCheckout(String orderId) async {
    final result = await _functions.httpsCallable('createPeachCheckout').call({
      'orderId': orderId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PeachCheckoutSession(
      checkoutId: data['checkoutId'] ?? '',
      checkoutUrl: data['checkoutUrl'] ?? '',
      entityId: data['entityId'] ?? '',
    );
  }

  Future<PeachMobileCheckoutSession> preparePeachMobileCheckout(
    String orderId,
  ) async {
    final result = await _functions
        .httpsCallable('preparePeachMobileCheckout')
        .call({'orderId': orderId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return PeachMobileCheckoutSession(
      checkoutId: data['checkoutId'] ?? '',
      entityId: data['entityId'] ?? '',
      amount: data['amount'] ?? '',
      currency: data['currency'] ?? '',
    );
  }

  Future<PeachPaymentStatus> verifyPeachPayment({
    required String orderId,
    required String checkoutId,
  }) async {
    final result = await _functions.httpsCallable('verifyPeachPayment').call({
      'orderId': orderId,
      'checkoutId': checkoutId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PeachPaymentStatus(
      paid: data['paid'] == true,
      resultCode: data['resultCode'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Future<PeachPaymentStatus> verifyPeachMobilePayment({
    required String orderId,
    required String resourcePath,
    String? checkoutId,
  }) async {
    final payload = {'orderId': orderId, 'resourcePath': resourcePath};
    if (checkoutId != null) {
      payload['checkoutId'] = checkoutId;
    }
    final result = await _functions
        .httpsCallable('verifyPeachMobilePayment')
        .call(payload);
    final data = Map<String, dynamic>.from(result.data as Map);
    return PeachPaymentStatus(
      paid: data['paid'] == true,
      resultCode: data['resultCode'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Stream<List<MessageModel>> getMessages(String userId, String otherId) {
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
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  Future<void> sendMessage(MessageModel message) async {
    await _db.collection('messages').add(message.toMap());
  }

  Future<String> uploadChatImage({
    required String uid,
    required File file,
  }) async {
    final path =
        'chat_attachments/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
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
}

class PeachCheckoutSession {
  final String checkoutId;
  final String checkoutUrl;
  final String entityId;

  const PeachCheckoutSession({
    required this.checkoutId,
    required this.checkoutUrl,
    required this.entityId,
  });
}

class PeachMobileCheckoutSession {
  final String checkoutId;
  final String entityId;
  final String amount;
  final String currency;

  const PeachMobileCheckoutSession({
    required this.checkoutId,
    required this.entityId,
    required this.amount,
    required this.currency,
  });
}

class PeachPaymentStatus {
  final bool paid;
  final String resultCode;
  final String description;

  const PeachPaymentStatus({
    required this.paid,
    required this.resultCode,
    required this.description,
  });
}
