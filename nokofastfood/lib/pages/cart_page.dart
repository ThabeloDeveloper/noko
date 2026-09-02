import 'package:flutter/material.dart';
import 'package:nokofastfood/data/models/app_settings_model.dart';
import 'package:nokofastfood/pages/checkout_page.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../data/providers/cart_provider.dart';
import '../data/services/firebase_service.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cartItems = cart.items.values.toList();
    final service = FirebaseService();

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        backgroundColor: MyColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Cart",
          style: TextStyle(
            color: MyColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MyColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: MyColors.secondaryText,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Your cart is empty",
                    style: TextStyle(
                      color: MyColors.secondaryText,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MyColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final image = ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.product.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 70,
                                      height: 70,
                                      color: MyColors.elevatedSurface,
                                      child: const Icon(
                                        Icons.fastfood,
                                        color: MyColors.secondaryText,
                                      ),
                                    ),
                              ),
                            );
                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MyColors.primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "R${item.product.price.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: MyColors.goldAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                            final stepper = _CartQuantityStepper(
                              quantity: item.quantity,
                              onDecrease: () =>
                                  cart.removeSingleItem(item.product.id),
                              onIncrease: () => cart.addItem(item.product),
                            );

                            if (constraints.maxWidth < 340) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  image,
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        details,
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: stepper,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                image,
                                const SizedBox(width: 15),
                                Expanded(child: details),
                                const SizedBox(width: 12),
                                stepper,
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: MyColors.surfaceCard,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        "Subtotal",
                        "R${cart.subtotal.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<AppSettingsModel>(
                        stream: service.watchAppSettings(),
                        builder: (context, snapshot) {
                          final settings =
                              snapshot.data ?? AppSettingsModel.defaults();
                          return Column(
                            children: [
                              _buildSummaryRow(
                                "Delivery Estimate",
                                "R${cart.deliveryFeeFor(delivery: true, configuredDeliveryFee: settings.deliveryFee).toStringAsFixed(2)}",
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Collection can be selected at checkout for R0.00.',
                                style: TextStyle(
                                  color: MyColors.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(color: MyColors.divider, height: 30),
                      StreamBuilder<AppSettingsModel>(
                        stream: service.watchAppSettings(),
                        builder: (context, snapshot) {
                          final settings =
                              snapshot.data ?? AppSettingsModel.defaults();
                          return _buildSummaryRow(
                            "Delivery Total",
                            "R${cart.totalAmountFor(delivery: true, configuredDeliveryFee: settings.deliveryFee).toStringAsFixed(2)}",
                            isTotal: true,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutPage(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: MyColors.buttonPrimary,
                            foregroundColor: MyColors.buttonPrimaryText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text(
                            "Checkout",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? MyColors.primaryText : MyColors.secondaryText,
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? MyColors.goldAccent : MyColors.primaryText,
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _CartQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CartQuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: MyColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MyColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: quantity <= 1 ? 'Remove item' : 'Decrease quantity',
            onPressed: onDecrease,
            style: IconButton.styleFrom(
              minimumSize: const Size(42, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              quantity <= 1 ? Icons.delete_outline : Icons.remove,
              color: MyColors.primary,
              size: 20,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MyColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add one more',
            onPressed: onIncrease,
            style: IconButton.styleFrom(
              minimumSize: const Size(42, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(
              Icons.add,
              color: MyColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
