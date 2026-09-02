import 'package:flutter_test/flutter_test.dart';
import 'package:noko_admin/data/models/admin_user_model.dart';
import 'package:noko_admin/data/models/order_model.dart';
import 'package:noko_admin/data/models/product_model.dart';
import 'package:noko_admin/data/models/restaurant_model.dart';

void main() {
  test('product model uses safe defaults from partial data', () {
    final product = ProductModel.fromMap({'name': 'Chips'}, 'chips-1');

    expect(product.id, 'chips-1');
    expect(product.name, 'Chips');
    expect(product.price, 0);
    expect(product.available, false);
  });

  test('restaurant model supports uploaded image urls', () {
    final restaurant = RestaurantModel.fromMap({
      'name': 'Noko Kitchen',
      'imageUrl': 'https://example.com/kitchen.jpg',
      'isOpen': true,
    }, 'restaurant-1');

    expect(restaurant.imageUrl, 'https://example.com/kitchen.jpg');
    expect(restaurant.isOpen, true);
  });

  test('admin order model tolerates partial order data', () {
    final order = OrderModel.fromMap({'total': 120, 'status': 'pending'}, 'o1');

    expect(order.id, 'o1');
    expect(order.total, 120);
    expect(order.paymentStatus, 'pending');
  });

  test('admin user model defaults to customer role', () {
    final user = AdminUserModel.fromMap({'email': 'test@noko.app'}, 'u1');

    expect(user.id, 'u1');
    expect(user.email, 'test@noko.app');
    expect(user.role, 'customer');
  });
}
