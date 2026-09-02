import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/data/models/driver_order.dart';
import 'package:noko_driver/data/services/firebase_service.dart';
import 'package:noko_driver/pages/order_detail_page.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _service = FirebaseService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _service.updateMessagingToken(_uid);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(service: _service, uid: _uid),
      _OrdersTab(
        title: 'Out for Delivery',
        stream: _service.watchAssignedOrders(_uid),
        emptyText:
            'No assigned delivery orders. Orders appear here after the restaurant sends them out for delivery.',
        actionLabel: 'Open',
      ),
      _HistoryTab(service: _service, uid: _uid),
      _ProfileTab(service: _service, uid: _uid),
    ];

    return Scaffold(
      backgroundColor: MyColors.background,
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final FirebaseService service;
  final String uid;

  const _DashboardTab({required this.service, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: service.watchDriver(uid),
      builder: (context, profileSnapshot) {
        final data = profileSnapshot.data?.data() ?? {};
        final online = data['driverOnline'] == true;
        return StreamBuilder<List<DriverOrder>>(
          stream: service.watchAssignedOrders(uid),
          builder: (context, activeSnapshot) {
            final active = activeSnapshot.data ?? [];
            return StreamBuilder<List<DriverOrder>>(
              stream: service.watchDeliveryHistory(uid),
              builder: (context, historySnapshot) {
                final history = historySnapshot.data ?? [];
                final delivered = history
                    .where((order) => order.status == 'delivered')
                    .length;
                final earnings = service.deliveryEarnings(history);
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: MyColors.primary,
                      title: const Text('Restaurant Driver'),
                      actions: [
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.list(
                        children: [
                          _AvailabilityCard(
                            online: online,
                            onChanged: (value) =>
                                service.updateDriverAvailability(
                                  uid: uid,
                                  online: value,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Active',
                                  value: active.length.toString(),
                                  icon: Icons.route_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Delivered',
                                  value: delivered.toString(),
                                  icon: Icons.check_circle_outline,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Earnings',
                                  value: 'R${earnings.toStringAsFixed(0)}',
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Assigned Delivery',
                            style: TextStyle(
                              color: MyColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (active.isEmpty)
                            const _EmptyPanel(
                              'No order is out for delivery under your driver account.',
                            )
                          else
                            _OrderCard(
                              order: active.first,
                              actionLabel: 'Open',
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final String title;
  final Stream<List<DriverOrder>> stream;
  final String emptyText;
  final String actionLabel;

  const _OrdersTab({
    required this.title,
    required this.stream,
    required this.emptyText,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(title: Text(title), backgroundColor: MyColors.primary),
      body: StreamBuilder<List<DriverOrder>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) return _EmptyPanel(emptyText);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _OrderCard(order: orders[index], actionLabel: actionLabel);
            },
          );
        },
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final FirebaseService service;
  final String uid;

  const _HistoryTab({required this.service, required this.uid});

  @override
  Widget build(BuildContext context) {
    return _OrdersTab(
      title: 'Delivery History',
      stream: service.watchDeliveryHistory(uid),
      emptyText: 'Delivered and failed delivery orders will appear here.',
      actionLabel: 'Details',
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final FirebaseService service;
  final String uid;

  const _ProfileTab({required this.service, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: MyColors.primary,
      ),
      body: StreamBuilder(
        stream: service.watchDriver(uid),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Driver',
                      style: const TextStyle(
                        color: MyColors.primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['email'] ??
                          FirebaseAuth.instance.currentUser?.email ??
                          '',
                      style: const TextStyle(color: MyColors.secondaryText),
                    ),
                    const Divider(height: 28),
                    _ProfileRow('Phone', data['phone'] ?? 'Not set'),
                    _ProfileRow('Role', data['role'] ?? 'driver'),
                    _ProfileRow(
                      'Availability',
                      data['driverOnline'] == true ? 'Online' : 'Offline',
                    ),
                    _ProfileRow(
                      'Approval',
                      data['driverApproved'] == false
                          ? 'Pending approval'
                          : 'Approved',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.sendPasswordResetEmail(
                  email: FirebaseAuth.instance.currentUser?.email ?? '',
                ),
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Send password reset'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 16),
              const _EmptyPanel(
                'Driver registration, document uploads, and approval are managed by the admin app.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DriverOrder order;
  final String actionLabel;

  const _OrderCard({required this.order, required this.actionLabel});

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
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              Chip(label: Text(_label(order.status))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.items.length} items - R${order.total.toStringAsFixed(2)}',
            style: const TextStyle(color: MyColors.secondaryText),
          ),
          const SizedBox(height: 6),
          Text(
            order.deliveryAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MyColors.secondaryText),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(orderId: order.id),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
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

class _AvailabilityCard extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;

  const _AvailabilityCard({required this.online, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: online,
        onChanged: onChanged,
        title: const Text(
          'Restaurant driver access',
          style: TextStyle(color: MyColors.primaryText),
        ),
        subtitle: Text(
          online
              ? 'You can view restaurant-assigned delivery orders.'
              : 'You are offline. Ask the restaurant/admin to assign orders.',
          style: const TextStyle(color: MyColors.secondaryText),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, color: MyColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(label, style: const TextStyle(color: MyColors.secondaryText)),
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

class _EmptyPanel extends StatelessWidget {
  final String text;

  const _EmptyPanel(this.text);

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MyColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ),
          Text(value, style: const TextStyle(color: MyColors.primaryText)),
        ],
      ),
    );
  }
}
