import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/order_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/pages/delivery_map_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OrderDetailsPage extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(color: MyColors.primaryText),
        ),
        backgroundColor: MyColors.background,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(),
            const SizedBox(height: 24),
            _buildTrackingSection(context),
            const SizedBox(height: 24),
            _buildQRSection(),
            const SizedBox(height: 24),
            _buildItemsList(),
            const SizedBox(height: 24),
            _buildTotalSection(),
            const SizedBox(height: 24),
            _buildAddressSection(),
            if (order.manualRefundRequired) ...[
              const SizedBox(height: 24),
              _buildManualRefundNotice(),
            ],
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection(BuildContext context) {
    final isCollection = order.fulfillmentType == 'collection';
    final steps = isCollection
        ? ['pending', 'preparing', 'delivered']
        : ['pending', 'preparing', 'out_for_delivery', 'delivered'];
    final currentIndex = order.status == 'cancelled'
        ? -1
        : steps.indexOf(order.status).clamp(0, steps.length - 1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Tracking',
            style: TextStyle(
              color: MyColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (order.status == 'cancelled')
            const Text(
              'This order was cancelled.',
              style: TextStyle(color: MyColors.error),
            )
          else
            Column(
              children: [
                LinearProgressIndicator(
                  value: (currentIndex + 1) / steps.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < steps.length; index++)
                      Chip(
                        label: Text(_label(steps[index])),
                        backgroundColor: index <= currentIndex
                            ? MyColors.primary.withValues(alpha: 0.35)
                            : MyColors.elevatedSurface,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isCollection
                      ? order.status == 'delivered'
                            ? 'Collected'
                            : 'Preparing for collection'
                      : order.status == 'delivered'
                      ? 'Delivered'
                      : 'Estimated delivery: about ${order.etaMinutes} minutes',
                  style: const TextStyle(color: MyColors.secondaryText),
                ),
                if (!isCollection && order.routeDistanceMeters != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Road distance: ${(order.routeDistanceMeters! / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(color: MyColors.secondaryText),
                  ),
                ],
                if (!isCollection) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryMapPage(orderId: order.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open live map'),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Order #${order.orderNumber}",
              style: const TextStyle(
                color: MyColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Placed on ${order.createdAt.toString().split('.')[0]}",
              style: const TextStyle(
                color: MyColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor()),
          ),
          child: Text(
            order.status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (order.status) {
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

  Widget _buildQRSection() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: jsonEncode(order.toQrPayload()),
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Scan for pickup/delivery verification",
            style: TextStyle(color: MyColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Items",
          style: TextStyle(
            color: MyColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...order.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: const TextStyle(color: MyColors.primaryText),
                      ),
                      Text(
                        "Qty: ${item['quantity']}",
                        style: const TextStyle(
                          color: MyColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "R${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}",
                  style: const TextStyle(color: MyColors.primaryText),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalSection() {
    final isCollection = order.fulfillmentType == 'collection';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTotalRow("Subtotal", "R${order.subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          if (order.discount > 0) ...[
            _buildTotalRow(
              "Discount",
              "-R${order.discount.toStringAsFixed(2)}",
            ),
            const SizedBox(height: 8),
          ],
          _buildTotalRow(
            isCollection ? "Collection Fee" : "Delivery Fee",
            "R${order.deliveryFee.toStringAsFixed(2)}",
          ),
          if (!isCollection && order.routeDistanceMeters != null) ...[
            const SizedBox(height: 8),
            _buildTotalRow(
              "Road Distance",
              "${(order.routeDistanceMeters! / 1000).toStringAsFixed(1)} km",
            ),
          ],
          const Divider(color: MyColors.divider, height: 24),
          _buildTotalRow(
            "Total",
            "R${order.total.toStringAsFixed(2)}",
            isBold: true,
          ),
          const SizedBox(height: 8),
          _buildTotalRow("Payment", _label(order.paymentMethod)),
          const SizedBox(height: 8),
          _buildTotalRow("Payment Status", _label(order.paymentStatus)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? MyColors.primaryText : MyColors.secondaryText,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? MyColors.goldAccent : MyColors.primaryText,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    final isCollection = order.fulfillmentType == 'collection';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCollection ? "Collection" : "Delivery Address",
          style: TextStyle(
            color: MyColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCollection
              ? 'Collect from the selected restaurant.'
              : order.deliveryAddress,
          style: const TextStyle(color: MyColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildManualRefundNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.warning),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MyColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Refund required: the restaurant must manually send back the money for this paid Peach order.',
              style: TextStyle(color: MyColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (order.status != 'pending' && order.status != 'preparing') {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _cancelOrder(context),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancel Order'),
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
      await FirebaseService().cancelOrder(order.id);
      if (context.mounted) {
        Navigator.pop(context);
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

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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
