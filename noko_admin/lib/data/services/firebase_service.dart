import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/admin_user_model.dart';
import '../models/app_settings_model.dart';
import '../models/menu_category_model.dart';
import '../models/notification_campaign_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/restaurant_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Stream<AppSettingsModel> watchAppSettings() {
    return _firestore
        .collection('appSettings')
        .doc('platform')
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return AppSettingsModel.defaults();
      }
      return AppSettingsModel.fromFirestore(doc);
    });
  }

  Future<void> updateDeliveryFee(double deliveryFee) async {
    await _firestore.collection('appSettings').doc('platform').set({
      'deliveryFee': deliveryFee,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ProductModel>> getProducts() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    });
  }

  Stream<List<MenuCategoryModel>> getMenuCategories() {
    return _firestore.collection('menuCategories').snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => MenuCategoryModel.fromFirestore(doc))
          .toList();
      categories.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
      return categories;
    });
  }

  Future<void> createMenuCategory({
    required String name,
    required int sortOrder,
  }) async {
    final normalized = _categoryId(name);
    await _firestore.collection('menuCategories').doc(normalized).set({
      'name': name.trim(),
      'sortOrder': sortOrder,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMenuCategory(MenuCategoryModel category) async {
    await _firestore.collection('menuCategories').doc(category.id).set({
      'name': category.name.trim(),
      'sortOrder': category.sortOrder,
      'active': category.active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMenuCategoryStatus(String id, bool active) async {
    await _firestore.collection('menuCategories').doc(id).set({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteMenuCategory(String id) async {
    await _firestore.collection('menuCategories').doc(id).delete();
  }

  Stream<List<RestaurantModel>> getRestaurants() {
    return _firestore.collection('restaurants').snapshots().map((snapshot) {
      final restaurants = snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .toList();
      restaurants.sort((a, b) => a.name.compareTo(b.name));
      return restaurants;
    });
  }

  Stream<List<OrderModel>> getOrders() {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<List<AdminUserModel>> getUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AdminUserModel.fromFirestore(doc))
          .toList();
      users.sort((a, b) => a.name.compareTo(b.name));
      return users;
    });
  }

  Stream<List<NotificationCampaignModel>> getNotificationCampaigns() {
    return _firestore.collection('notificationCampaigns').snapshots().map((
      snapshot,
    ) {
      final campaigns = snapshot.docs
          .map((doc) => NotificationCampaignModel.fromFirestore(doc))
          .toList();
      campaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return campaigns;
    });
  }

  Future<void> createRestaurant(Map<String, dynamic> data) async {
    await _firestore.collection('restaurants').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRestaurant(String id, Map<String, dynamic> data) async {
    await _firestore.collection('restaurants').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRestaurant(String id) async {
    await _firestore.collection('restaurants').doc(id).delete();
  }

  Future<void> updateRestaurantStatus(String id, bool isOpen) async {
    await updateRestaurant(id, {'isOpen': isOpen});
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    await _firestore.collection('products').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _firestore.collection('products').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  Future<void> updateProductAvailability(String id, bool available) async {
    await updateProduct(id, {'available': available});
  }

  String _categoryId(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : normalized;
  }

  Future<void> updateOrder({
    required String id,
    String? status,
    String? paymentStatus,
    String? driverId,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (status != null) {
      data['status'] = status;
    }
    if (paymentStatus != null) {
      data['paymentStatus'] = paymentStatus;
    }
    if (driverId != null) {
      data['driverId'] = driverId.isEmpty ? null : driverId;
    }
    await _firestore.collection('orders').doc(id).update(data);
  }

  Future<void> createManagedUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    await _functions.httpsCallable('createManagedUser').call({
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
    });
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _functions.httpsCallable('setManagedUserRole').call({
      'uid': uid,
      'role': role,
    });
  }

  Future<void> deleteManagedUser(String uid) async {
    await _functions.httpsCallable('deleteManagedUser').call({'uid': uid});
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<HttpsCallableResult<dynamic>> sendNotification({
    required String title,
    required String body,
    required String targetRole,
  }) {
    return _functions.httpsCallable('sendAdminNotification').call({
      'title': title,
      'body': body,
      'targetRole': targetRole,
    });
  }

  Future<String?> pickAndUploadImage(String folder) async {
    await _verifyAdminUploadAccess();

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) {
      return null;
    }

    final extension = _extensionFor(image.name);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref('admin_uploads/$folder/$fileName');
    await ref.putData(
      await image.readAsBytes(),
      SettableMetadata(contentType: _contentTypeFor(extension)),
    );
    return ref.getDownloadURL();
  }

  Future<void> _verifyAdminUploadAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in as an admin before uploading images.');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'];
    if (role != 'admin') {
      throw Exception(
        'This account is not marked as admin in Firestore. Set users/${user.uid}/role to admin, then sign in again.',
      );
    }
  }

  String _extensionFor(String name) {
    final parts = name.split('.');
    if (parts.length < 2) {
      return 'jpg';
    }
    final extension = parts.last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      return extension;
    }
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    if (extension == 'png') {
      return 'image/png';
    }
    if (extension == 'webp') {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
