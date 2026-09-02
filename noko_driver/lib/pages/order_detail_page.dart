import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/data/models/driver_order.dart';
import 'package:noko_driver/data/models/restaurant.dart';
import 'package:noko_driver/data/services/firebase_service.dart';
import 'package:noko_driver/pages/chat_page.dart';
import 'package:noko_driver/pages/delivery_map_page.dart';
import 'package:noko_driver/pages/scanner_page.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _service = FirebaseService();
  StreamSubscription<Position>? _locationSub;
  bool _sharingLocation = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final driverId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DriverOrder?>(
      stream: _service.watchOrder(widget.orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        if (order == null) {
          return const Scaffold(
            backgroundColor: MyColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<Restaurant?>(
          future: _service.getRestaurant(order.restaurantId),
          builder: (context, restaurantSnapshot) {
            final restaurant = restaurantSnapshot.data;
            final assignedToMe = order.driverId == driverId;
            return Scaffold(
              backgroundColor: MyColors.background,
              appBar: AppBar(
                title: Text('Order #${order.orderNumber}'),
                backgroundColor: MyColors.primary,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusPanel(order: order),
                  const SizedBox(height: 12),
                  _RestaurantPanel(restaurant: restaurant),
                  const SizedBox(height: 12),
                  _DeliveryPanel(order: order),
                  const SizedBox(height: 12),
                  _ItemsPanel(order: order),
                  const SizedBox(height: 12),
                  _CommunicationPanel(
                    order: order,
                    restaurant: restaurant,
                    onCallRestaurant:
                        restaurant?.phone == null || restaurant!.phone.isEmpty
                        ? null
                        : () => _call(restaurant.phone),
                    onChatCustomer: assignedToMe
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                receiverId: order.customerId,
                                title: 'Customer chat',
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _ActionPanel(
                    order: order,
                    assignedToMe: assignedToMe,
                    sharingLocation: _sharingLocation,
                    busy: _busy,
                    onToggleLocation: assignedToMe
                        ? () => _toggleLocationSharing(order.id)
                        : null,
                    onOpenMap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeliveryMapPage(orderId: order.id),
                      ),
                    ),
                    onNavigate: () => _navigateTo(order),
                    onScan: assignedToMe
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScannerPage(orderId: order.id),
                            ),
                          )
                        : null,
                    onDelivered: assignedToMe && order.canDeliver
                        ? () => _confirmDelivered(order)
                        : null,
                    onFail: assignedToMe ? () => _failDelivery(order.id) : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: MyColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLocationSharing(String orderId) async {
    if (_sharingLocation) {
      await _locationSub?.cancel();
      _locationSub = null;
      setState(() => _sharingLocation = false);
      return;
    }

    try {
      final current = await _service.ensureLocation();
      await _service.updateDriverLocation(
        orderId: orderId,
        latitude: current.latitude,
        longitude: current.longitude,
      );
      _locationSub = _service.locationStream().listen((position) {
        _service.updateDriverLocation(
          orderId: orderId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
      setState(() => _sharingLocation = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: MyColors.error),
        );
      }
    }
  }

  Future<void> _navigateTo(DriverOrder order) async {
    final query =
        order.deliveryLatitude != null && order.deliveryLongitude != null
        ? '${order.deliveryLatitude},${order.deliveryLongitude}'
        : Uri.encodeComponent(order.deliveryAddress);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$query',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _confirmDelivered(DriverOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark delivered?'),
        content: Text(
          'Confirm that order #${order.orderNumber} was delivered to the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark delivered'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.markDelivered(order.id));
  }

  Future<void> _failDelivery(String orderId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Failed delivery'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Customer unavailable, wrong address, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await _run(() => _service.failDelivery(orderId: orderId, reason: reason));
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}

class _StatusPanel extends StatelessWidget {
  final DriverOrder order;

  const _StatusPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _label(order.status),
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(label: Text(_label(order.paymentStatus))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ETA ${order.etaMinutes} min - Delivery fee R${order.deliveryFee.toStringAsFixed(2)}',
            style: const TextStyle(color: MyColors.secondaryText),
          ),
          if (order.routeDistanceMeters != null) ...[
            const SizedBox(height: 6),
            Text(
              'Restaurant to customer: ${(order.routeDistanceMeters! / 1000).toStringAsFixed(1)} km by road',
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestaurantPanel extends StatelessWidget {
  final Restaurant? restaurant;

  const _RestaurantPanel({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup',
            style: TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            restaurant?.name ?? 'Restaurant',
            style: const TextStyle(color: MyColors.primaryText),
          ),
          Text(
            restaurant?.address ?? 'Pickup address not set',
            style: const TextStyle(color: MyColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPanel extends StatelessWidget {
  final DriverOrder order;

  const _DeliveryPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drop-off',
            style: TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress,
            style: const TextStyle(color: MyColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ItemsPanel extends StatelessWidget {
  final DriverOrder order;

  const _ItemsPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items',
            style: TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${item['quantity'] ?? 1}x ${item['name'] ?? 'Item'}',
                style: const TextStyle(color: MyColors.secondaryText),
              ),
            ),
          ),
          const Divider(),
          Text(
            'Total: R${order.total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunicationPanel extends StatelessWidget {
  final DriverOrder order;
  final Restaurant? restaurant;
  final VoidCallback? onCallRestaurant;
  final VoidCallback? onChatCustomer;

  const _CommunicationPanel({
    required this.order,
    required this.restaurant,
    required this.onCallRestaurant,
    required this.onChatCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: onCallRestaurant,
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call restaurant'),
          ),
          OutlinedButton.icon(
            onPressed: onChatCustomer,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat customer'),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final DriverOrder order;
  final bool assignedToMe;
  final bool sharingLocation;
  final bool busy;
  final VoidCallback? onToggleLocation;
  final VoidCallback onOpenMap;
  final VoidCallback onNavigate;
  final VoidCallback? onScan;
  final VoidCallback? onDelivered;
  final VoidCallback? onFail;

  const _ActionPanel({
    required this.order,
    required this.assignedToMe,
    required this.sharingLocation,
    required this.busy,
    required this.onToggleLocation,
    required this.onOpenMap,
    required this.onNavigate,
    required this.onScan,
    required this.onDelivered,
    required this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (assignedToMe && order.canDeliver) ...[
            OutlinedButton.icon(
              onPressed: onToggleLocation,
              icon: Icon(
                sharingLocation
                    ? Icons.location_disabled_outlined
                    : Icons.my_location,
              ),
              label: Text(
                sharingLocation ? 'Stop live location' : 'Share live location',
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open route map'),
            ),
            OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Open navigation'),
            ),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan customer QR'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onDelivered,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark delivered'),
            ),
            OutlinedButton.icon(
              onPressed: onFail,
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report failed delivery'),
            ),
          ] else if (assignedToMe) ...[
            Text(
              order.status == 'delivered'
                  ? 'This delivery is already marked delivered.'
                  : 'This order is not out for delivery.',
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ] else ...[
            const Text(
              'This order is not assigned to your driver account.',
              style: TextStyle(color: MyColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MyColors.divider),
      ),
      child: child,
    );
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
