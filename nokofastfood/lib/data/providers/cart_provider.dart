import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';

class CartProvider with ChangeNotifier {
  static const _storageKey = 'noko_customer_cart';
  final Map<String, CartItem> _items = {};
  bool _loaded = false;

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  int get totalQuantity {
    int total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.quantity;
    });
    return total;
  }

  double get subtotal {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.total;
    });
    return total;
  }

  double deliveryFeeFor({
    required bool delivery,
    double configuredDeliveryFee = 15,
  }) {
    return delivery && subtotal > 0 ? configuredDeliveryFee : 0.0;
  }

  double totalAmountFor({
    required bool delivery,
    double configuredDeliveryFee = 15,
  }) {
    return subtotal +
        deliveryFeeFor(
          delivery: delivery,
          configuredDeliveryFee: configuredDeliveryFee,
        );
  }

  double get deliveryFee => deliveryFeeFor(delivery: true);

  double get totalAmount => totalAmountFor(delivery: true);

  bool get loaded => _loaded;

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List;
      for (final item in decoded) {
        final map = Map<String, dynamic>.from(item as Map);
        final product = ProductModel.fromMap(
          Map<String, dynamic>.from(map['product'] as Map),
          map['productId'] as String,
        );
        _items[product.id] = CartItem(
          product: product,
          quantity: (map['quantity'] ?? 1) as int,
        );
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void addItem(ProductModel product) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(product.id, () => CartItem(product: product));
    }
    notifyListeners();
    _persist();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _persist();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
    _persist();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _items.values
        .map(
          (item) => {
            'productId': item.product.id,
            'quantity': item.quantity,
            'product': item.product.toMap(),
          },
        )
        .toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}
