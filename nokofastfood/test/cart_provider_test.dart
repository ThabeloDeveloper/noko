import 'package:flutter_test/flutter_test.dart';
import 'package:nokofastfood/data/models/product_model.dart';
import 'package:nokofastfood/data/models/promo_code_model.dart';
import 'package:nokofastfood/data/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cart totals update as items are added and removed', () {
    final cart = CartProvider();
    final product = ProductModel(
      id: 'burger-1',
      restaurantId: 'restaurant123',
      name: 'Burger',
      description: 'Classic burger',
      price: 50,
      category: 'Burgers',
      imageUrl: '',
      available: true,
    );

    cart.addItem(product);
    cart.addItem(product);

    expect(cart.itemCount, 1);
    expect(cart.totalQuantity, 2);
    expect(cart.subtotal, 100);
    expect(cart.deliveryFee, 15);
    expect(cart.totalAmount, 115);

    cart.removeSingleItem(product.id);

    expect(cart.totalQuantity, 1);
    expect(cart.subtotal, 50);
  });

  test('promo code calculates percentage discount', () {
    final promo = PromoCodeModel(
      id: 'SAVE10',
      code: 'SAVE10',
      type: 'percent',
      value: 10,
      minSubtotal: 50,
      active: true,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    expect(promo.discountFor(200), 20);
    expect(promo.discountFor(30), 0);
  });
}
