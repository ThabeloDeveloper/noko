import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/order_model.dart';
import 'package:nokofastfood/data/providers/cart_provider.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/pages/cart_page.dart';
import 'package:nokofastfood/pages/order_details_page.dart';
import 'package:provider/provider.dart';

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final FirebaseService _firebaseService = FirebaseService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        backgroundColor: MyColors.background,
        body: Center(
          child: Text(
            'Please log in to view orders',
            style: TextStyle(color: MyColors.primaryText),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(color: MyColors.primaryText),
        ),
        backgroundColor: MyColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _firebaseService.getCustomerOrders(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: MyColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: MyColors.error),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders found',
                style: TextStyle(color: MyColors.secondaryText),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(
                order: order,
                service: _firebaseService,
                onReorder: () => _reorder(order),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _reorder(OrderModel order) async {
    try {
      final products = await _firebaseService
          .getProducts(order.restaurantId)
          .first;
      if (!mounted) return;
      final byId = {for (final product in products) product.id: product};
      final cart = context.read<CartProvider>();
      cart.clear();
      for (final item in order.items) {
        final product = byId[item['productId']];
        final quantity = (item['quantity'] ?? 1) as int;
        if (product != null && product.available) {
          for (var index = 0; index < quantity; index++) {
            cart.addItem(product);
          }
        }
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppBottomMessage(
          context,
          title: 'Reorder failed',
          message: 'Could not rebuild cart: $e',
          type: BottomAlertType.error,
        );
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final FirebaseService service;
  final VoidCallback onReorder;

  const _OrderCard({
    required this.order,
    required this.service,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: MyColors.surfaceCard,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsPage(order: order),
                  ),
                );
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderNumber}',
                          style: const TextStyle(
                            color: MyColors.primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${order.items.length} items - ${order.fulfillmentType == 'collection' ? 'Collection' : 'Delivery'} - R${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(color: MyColors.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${order.status.toUpperCase()}',
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: MyColors.secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.repeat_outlined),
                  label: const Text('Reorder'),
                ),
                if (order.status == 'pending' || order.status == 'preparing')
                  OutlinedButton.icon(
                    onPressed: () => _cancelOrder(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelOrderSheet(orderNumber: order.orderNumber),
    );
    if (confirmed != true) return;
    try {
      await service.cancelOrder(order.id);
      if (context.mounted) {
        showAppBottomMessage(
          context,
          title: 'Order cancelled',
          message: 'Order cancelled.',
          type: BottomAlertType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppBottomMessage(
          context,
          title: 'Cancellation failed',
          message: 'Could not cancel order: $e',
          type: BottomAlertType.error,
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return MyColors.warning;
      case 'preparing':
        return Colors.blue;
      case 'out_for_delivery':
        return MyColors.goldAccent;
      case 'delivered':
        return MyColors.success;
      case 'cancelled':
        return MyColors.error;
      default:
        return MyColors.secondaryText;
    }
  }
}

class _CancelOrderSheet extends StatelessWidget {
  final String orderNumber;

  const _CancelOrderSheet({required this.orderNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MyColors.divider),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: MyColors.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Cancel order?',
              style: TextStyle(
                color: MyColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #$orderNumber will be marked as cancelled.',
              style: const TextStyle(
                color: MyColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep order'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
