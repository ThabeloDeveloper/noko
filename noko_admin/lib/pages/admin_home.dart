import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../data/models/admin_user_model.dart';
import '../data/models/app_settings_model.dart';
import '../data/models/menu_category_model.dart';
import '../data/models/notification_campaign_model.dart';
import '../data/models/order_model.dart';
import '../data/models/product_model.dart';
import '../data/models/restaurant_model.dart';
import '../data/services/firebase_service.dart';
import '../data/services/location_address_service.dart';

const _roles = ['admin', 'driver', 'customer'];
const _orderStatuses = [
  'pending',
  'preparing',
  'out_for_delivery',
  'delivered',
  'cancelled',
];
const _paymentStatuses = ['pending', 'paid', 'completed', 'failed'];

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final FirebaseService _service = FirebaseService();
  int _selectedIndex = 0;

  final _destinations = const [
    _AdminDestination('Overview', Icons.dashboard_outlined),
    _AdminDestination('Restaurants', Icons.storefront_outlined),
    _AdminDestination('Menu', Icons.restaurant_menu_outlined),
    _AdminDestination('Orders', Icons.receipt_long_outlined),
    _AdminDestination('Users', Icons.people_outline),
    _AdminDestination('Drivers', Icons.delivery_dining_outlined),
    _AdminDestination('Analytics', Icons.insights_outlined),
    _AdminDestination('Notifications', Icons.campaign_outlined),
    _AdminDestination('Access', Icons.admin_panel_settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final title = _destinations[_selectedIndex].label;

    return Scaffold(
      backgroundColor: MyColors.background,
      drawer: isWide ? null : _buildDrawer(),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: MyColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MyColors.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: MyColors.secondaryText),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              backgroundColor: MyColors.surfaceCard,
              selectedIndex: _selectedIndex,
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIconTheme: const IconThemeData(
                color: MyColors.primaryText,
              ),
              unselectedIconTheme: const IconThemeData(
                color: MyColors.secondaryText,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: MyColors.primaryText,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: MyColors.secondaryText,
              ),
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: [
                for (final item in _destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _OverviewSection(service: _service),
                _RestaurantsSection(service: _service),
                _ProductsSection(service: _service),
                _OrdersSection(service: _service),
                _UsersSection(service: _service),
                _DriversSection(service: _service),
                _AnalyticsSection(service: _service),
                _NotificationsSection(service: _service),
                _AccessSection(service: _service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: MyColors.surfaceCard,
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text(
                'Noko Admin',
                style: TextStyle(
                  color: MyColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var index = 0; index < _destinations.length; index++)
              ListTile(
                selected: index == _selectedIndex,
                leading: Icon(_destinations[index].icon),
                title: Text(_destinations[index].label),
                selectedColor: MyColors.goldAccent,
                textColor: MyColors.secondaryText,
                iconColor: MyColors.secondaryText,
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminDestination {
  final String label;
  final IconData icon;

  const _AdminDestination(this.label, this.icon);
}

class _OverviewSection extends StatelessWidget {
  final FirebaseService service;

  const _OverviewSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RestaurantModel>>(
      stream: service.getRestaurants(),
      builder: (context, restaurantSnapshot) {
        return StreamBuilder<List<ProductModel>>(
          stream: service.getProducts(),
          builder: (context, productSnapshot) {
            return StreamBuilder<List<OrderModel>>(
              stream: service.getOrders(),
              builder: (context, orderSnapshot) {
                return StreamBuilder<List<AdminUserModel>>(
                  stream: service.getUsers(),
                  builder: (context, userSnapshot) {
                    if (_hasError([
                      restaurantSnapshot,
                      productSnapshot,
                      orderSnapshot,
                      userSnapshot,
                    ])) {
                      return const _StateMessage(
                        icon: Icons.error_outline,
                        title: 'Dashboard could not load',
                      );
                    }
                    if (!_hasData([
                      restaurantSnapshot,
                      productSnapshot,
                      orderSnapshot,
                      userSnapshot,
                    ])) {
                      return const _LoadingPanel();
                    }

                    final restaurants = restaurantSnapshot.data ?? [];
                    final products = productSnapshot.data ?? [];
                    final orders = orderSnapshot.data ?? [];
                    final users = userSnapshot.data ?? [];
                    final openRestaurants = restaurants
                        .where((item) => item.isOpen)
                        .length;
                    final inStock = products
                        .where((item) => item.available)
                        .length;
                    final activeOrders = orders
                        .where(
                          (item) =>
                              item.status != 'delivered' &&
                              item.status != 'cancelled',
                        )
                        .length;
                    final revenue = _revenueTotal(orders);

                    return _ScrollPanel(
                      children: [
                        _SectionHeader(
                          title: 'Operations Snapshot',
                          subtitle: 'Live totals from Firestore.',
                        ),
                        _MetricGrid(
                          metrics: [
                            _Metric(
                              'Open restaurants',
                              '$openRestaurants/${restaurants.length}',
                              Icons.storefront_outlined,
                            ),
                            _Metric(
                              'Menu items in stock',
                              '$inStock/${products.length}',
                              Icons.restaurant_menu_outlined,
                            ),
                            _Metric(
                              'Active orders',
                              '$activeOrders',
                              Icons.receipt_long_outlined,
                            ),
                            _Metric(
                              'Delivered revenue',
                              _money(revenue),
                              Icons.payments_outlined,
                            ),
                            _Metric(
                              'Customers',
                              '${users.where((u) => u.role == 'customer').length}',
                              Icons.person_outline,
                            ),
                            _Metric(
                              'Drivers',
                              '${users.where((u) => u.role == 'driver').length}',
                              Icons.delivery_dining_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionHeader(
                          title: 'Needs Attention',
                          subtitle: 'Quick view of operational gaps.',
                        ),
                        _AttentionList(
                          products: products,
                          orders: orders,
                          restaurants: restaurants,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RestaurantsSection extends StatefulWidget {
  final FirebaseService service;

  const _RestaurantsSection({required this.service});

  @override
  State<_RestaurantsSection> createState() => _RestaurantsSectionState();
}

class _RestaurantsSectionState extends State<_RestaurantsSection> {
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RestaurantModel>>(
      stream: widget.service.getRestaurants(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline,
            title: 'Restaurants could not load',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const _LoadingPanel();
        }

        final query = _search.text.toLowerCase();
        final restaurants = (snapshot.data ?? []).where((restaurant) {
          return [
            restaurant.name,
            restaurant.phone,
            restaurant.address,
            restaurant.location,
          ].any((value) => value.toLowerCase().contains(query));
        }).toList();

        return _ScrollPanel(
          children: [
            _Toolbar(
              title: 'Restaurants',
              actionLabel: 'Add restaurant',
              actionIcon: Icons.add_business_outlined,
              onAction: () => _openRestaurantDialog(context),
              child: _SearchField(
                controller: _search,
                hint: 'Search restaurants',
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (restaurants.isEmpty)
              const _StateMessage(
                icon: Icons.storefront_outlined,
                title: 'No restaurants found',
              )
            else
              for (final restaurant in restaurants)
                _RestaurantCard(
                  restaurant: restaurant,
                  onToggle: (value) =>
                      _updateStatus(context, restaurant.id, value),
                  onEdit: () => _openRestaurantDialog(context, restaurant),
                  onDelete: () => _deleteRestaurant(context, restaurant),
                ),
          ],
        );
      },
    );
  }

  Future<void> _openRestaurantDialog(
    BuildContext context, [
    RestaurantModel? restaurant,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RestaurantDialog(service: widget.service, restaurant: restaurant),
    );
    if (saved == true && context.mounted) {
      _snack(context, 'Restaurant saved.');
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    String id,
    bool value,
  ) async {
    try {
      await widget.service.updateRestaurantStatus(id, value);
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to update restaurant: $e', isError: true);
      }
    }
  }

  Future<void> _deleteRestaurant(
    BuildContext context,
    RestaurantModel restaurant,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete ${restaurant.name}?',
      'Products linked to this restaurant are not deleted automatically.',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.service.deleteRestaurant(restaurant.id);
      if (context.mounted) {
        _snack(context, 'Restaurant deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to delete restaurant: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _ProductsSection extends StatefulWidget {
  final FirebaseService service;

  const _ProductsSection({required this.service});

  @override
  State<_ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<_ProductsSection> {
  final _search = TextEditingController();
  String _restaurantId = 'all';
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RestaurantModel>>(
      stream: widget.service.getRestaurants(),
      builder: (context, restaurantSnapshot) {
        return StreamBuilder<List<ProductModel>>(
          stream: widget.service.getProducts(),
          builder: (context, productSnapshot) {
            return StreamBuilder<List<MenuCategoryModel>>(
              stream: widget.service.getMenuCategories(),
              builder: (context, categorySnapshot) {
                if (restaurantSnapshot.hasError ||
                    productSnapshot.hasError ||
                    categorySnapshot.hasError) {
                  return const _StateMessage(
                    icon: Icons.error_outline,
                    title: 'Menu could not load',
                  );
                }
                if (!restaurantSnapshot.hasData ||
                    !productSnapshot.hasData ||
                    !categorySnapshot.hasData) {
                  return const _LoadingPanel();
                }

                final restaurants = restaurantSnapshot.data ?? [];
                final products = productSnapshot.data ?? [];
                final categories = categorySnapshot.data ?? [];
                final categoryNames = _categoryNames(categories, products);
                if (_category != 'all' && !categoryNames.contains(_category)) {
                  _category = 'all';
                }
                final restaurantNames = {
                  for (final item in restaurants) item.id: item.name,
                };
                final query = _search.text.toLowerCase();
                final filtered = products.where((product) {
                  final matchesSearch = [
                    product.name,
                    product.description,
                    product.category,
                    restaurantNames[product.restaurantId] ?? '',
                  ].any((value) => value.toLowerCase().contains(query));
                  final matchesRestaurant =
                      _restaurantId == 'all' ||
                      product.restaurantId == _restaurantId;
                  final matchesCategory =
                      _category == 'all' || product.category == _category;
                  return matchesSearch && matchesRestaurant && matchesCategory;
                }).toList();

                return _ScrollPanel(
                  children: [
                    _MenuCategoryManager(
                      service: widget.service,
                      categories: categories,
                      products: products,
                    ),
                    _Toolbar(
                      title: 'Menu Items',
                      actionLabel: 'Add item',
                      actionIcon: Icons.add_outlined,
                      onAction: restaurants.isEmpty || categoryNames.isEmpty
                          ? null
                          : () => _openProductDialog(
                              context,
                              restaurants,
                              categories,
                              products,
                            ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 260,
                            child: _SearchField(
                              controller: _search,
                              hint: 'Search menu',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          _DropdownFilter(
                            value: _restaurantId,
                            values: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All restaurants'),
                              ),
                              for (final restaurant in restaurants)
                                DropdownMenuItem(
                                  value: restaurant.id,
                                  child: Text(restaurant.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _restaurantId = value ?? 'all'),
                          ),
                          _DropdownFilter(
                            value: _category,
                            values: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All categories'),
                              ),
                              for (final category in categoryNames)
                                DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _category = value ?? 'all'),
                          ),
                        ],
                      ),
                    ),
                    if (restaurants.isEmpty)
                      const _StateMessage(
                        icon: Icons.storefront_outlined,
                        title: 'Add a restaurant before adding menu items',
                      )
                    else if (categoryNames.isEmpty)
                      const _StateMessage(
                        icon: Icons.category_outlined,
                        title: 'Add a category before adding menu items',
                      )
                    else if (filtered.isEmpty)
                      const _StateMessage(
                        icon: Icons.restaurant_menu_outlined,
                        title: 'No menu items found',
                      )
                    else
                      for (final product in filtered)
                        _ProductCard(
                          product: product,
                          restaurantName:
                              restaurantNames[product.restaurantId] ??
                              'Unknown',
                          onToggle: (value) =>
                              _updateAvailability(context, product.id, value),
                          onEdit: () => _openProductDialog(
                            context,
                            restaurants,
                            categories,
                            products,
                            product,
                          ),
                          onDelete: () => _deleteProduct(context, product),
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

  List<String> _categoryNames(
    List<MenuCategoryModel> categories,
    List<ProductModel> products,
  ) {
    final names = categories
        .where((category) => category.active)
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final existing =
        products
            .map((product) => product.category.trim())
            .where((name) => name.isNotEmpty && !names.contains(name))
            .toList()
          ..sort();
    return [...names, ...existing.toSet()];
  }

  Future<void> _openProductDialog(
    BuildContext context,
    List<RestaurantModel> restaurants,
    List<MenuCategoryModel> categories,
    List<ProductModel> products, [
    ProductModel? product,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductDialog(
        service: widget.service,
        restaurants: restaurants,
        categories: _categoryNames(categories, products),
        product: product,
      ),
    );
    if (saved == true && context.mounted) {
      _snack(context, 'Menu item saved.');
    }
  }

  Future<void> _updateAvailability(
    BuildContext context,
    String id,
    bool value,
  ) async {
    try {
      await widget.service.updateProductAvailability(id, value);
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to update item: $e', isError: true);
      }
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    ProductModel product,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete ${product.name}?',
      'This menu item will no longer appear for customers.',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.service.deleteProduct(product.id);
      if (context.mounted) {
        _snack(context, 'Menu item deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to delete item: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _OrdersSection extends StatefulWidget {
  final FirebaseService service;

  const _OrdersSection({required this.service});

  @override
  State<_OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<_OrdersSection> {
  final _search = TextEditingController();
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: widget.service.getOrders(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<List<RestaurantModel>>(
          stream: widget.service.getRestaurants(),
          builder: (context, restaurantSnapshot) {
            return StreamBuilder<List<AdminUserModel>>(
              stream: widget.service.getUsers(),
              builder: (context, userSnapshot) {
                if (orderSnapshot.hasError ||
                    restaurantSnapshot.hasError ||
                    userSnapshot.hasError) {
                  return const _StateMessage(
                    icon: Icons.error_outline,
                    title: 'Orders could not load',
                  );
                }
                if (!orderSnapshot.hasData ||
                    !restaurantSnapshot.hasData ||
                    !userSnapshot.hasData) {
                  return const _LoadingPanel();
                }

                final orders = orderSnapshot.data ?? [];
                final restaurants = {
                  for (final item in restaurantSnapshot.data ?? [])
                    item.id: item.name,
                };
                final Map<String, AdminUserModel> users = {
                  for (final item in userSnapshot.data ?? []) item.id: item,
                };
                final drivers = users.values
                    .where((item) => item.role == 'driver')
                    .toList();
                final query = _search.text.toLowerCase();
                final filtered = orders.where((order) {
                  final customer = users[order.customerId];
                  final restaurant = restaurants[order.restaurantId] ?? '';
                  final matchesSearch = [
                    order.orderNumber,
                    order.id,
                    order.deliveryAddress,
                    customer?.name ?? '',
                    customer?.email ?? '',
                    restaurant,
                  ].any((value) => value.toLowerCase().contains(query));
                  final matchesStatus =
                      _status == 'all' || order.status == _status;
                  return matchesSearch && matchesStatus;
                }).toList();

                return _ScrollPanel(
                  children: [
                    _Toolbar(
                      title: 'Orders',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _SearchField(
                              controller: _search,
                              hint: 'Search orders',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          _DropdownFilter(
                            value: _status,
                            values: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All statuses'),
                              ),
                              for (final status in _orderStatuses)
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(_label(status)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _status = value ?? 'all'),
                          ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      const _StateMessage(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders found',
                      )
                    else
                      for (final order in filtered)
                        _OrderCard(
                          order: order,
                          restaurantName:
                              restaurants[order.restaurantId] ?? 'Unknown',
                          customer: users[order.customerId],
                          drivers: drivers,
                          onUpdate:
                              ({
                                String? status,
                                String? paymentStatus,
                                String? driverId,
                              }) => _updateOrder(
                                context,
                                order.id,
                                status: status,
                                paymentStatus: paymentStatus,
                                driverId: driverId,
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

  Future<void> _updateOrder(
    BuildContext context,
    String id, {
    String? status,
    String? paymentStatus,
    String? driverId,
  }) async {
    try {
      await widget.service.updateOrder(
        id: id,
        status: status,
        paymentStatus: paymentStatus,
        driverId: driverId,
      );
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to update order: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _UsersSection extends StatelessWidget {
  final FirebaseService service;

  const _UsersSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return _PeopleSection(service: service, title: 'Users');
  }
}

class _DriversSection extends StatelessWidget {
  final FirebaseService service;

  const _DriversSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return _PeopleSection(
      service: service,
      title: 'Drivers',
      lockedRole: 'driver',
    );
  }
}

class _PeopleSection extends StatefulWidget {
  final FirebaseService service;
  final String title;
  final String? lockedRole;

  const _PeopleSection({
    required this.service,
    required this.title,
    this.lockedRole,
  });

  @override
  State<_PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends State<_PeopleSection> {
  final _search = TextEditingController();
  String _role = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUserModel>>(
      stream: widget.service.getUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline,
            title: '${widget.title} could not load',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const _LoadingPanel();
        }

        final query = _search.text.toLowerCase();
        final role = widget.lockedRole ?? _role;
        final users = (snapshot.data ?? []).where((user) {
          final matchesRole = role == 'all' || user.role == role;
          final matchesSearch = [
            user.name,
            user.email,
            user.phone,
            user.role,
          ].any((value) => value.toLowerCase().contains(query));
          return matchesRole && matchesSearch;
        }).toList();

        return _ScrollPanel(
          children: [
            _Toolbar(
              title: widget.title,
              actionLabel: widget.lockedRole == 'driver'
                  ? 'Add driver'
                  : 'Add account',
              actionIcon: Icons.person_add_alt_outlined,
              onAction: () => _openCreateUserDialog(context, widget.lockedRole),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 280,
                    child: _SearchField(
                      controller: _search,
                      hint: 'Search people',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (widget.lockedRole == null)
                    _DropdownFilter(
                      value: _role,
                      values: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All roles'),
                        ),
                        for (final role in _roles)
                          DropdownMenuItem(
                            value: role,
                            child: Text(_label(role)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _role = value ?? 'all'),
                    ),
                ],
              ),
            ),
            if (users.isEmpty)
              _StateMessage(
                icon: Icons.people_outline,
                title: widget.lockedRole == 'driver'
                    ? 'No drivers found'
                    : 'No users found',
              )
            else
              for (final user in users)
                _UserCard(
                  user: user,
                  onRoleChanged: (role) => _updateRole(context, user, role),
                  onReset: () => _resetPassword(context, user.email),
                  onDelete: () => _deleteUser(context, user),
                ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateUserDialog(BuildContext context, String? role) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateUserDialog(service: widget.service, role: role),
    );
    if (created == true && context.mounted) {
      _snack(context, 'Account created.');
    }
  }

  Future<void> _updateRole(
    BuildContext context,
    AdminUserModel user,
    String role,
  ) async {
    try {
      await widget.service.updateUserRole(user.id, role);
      if (context.mounted) {
        _snack(context, 'Role updated.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to update role: $e', isError: true);
      }
    }
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    if (email.isEmpty) {
      _snack(context, 'This user has no email address.', isError: true);
      return;
    }
    try {
      await widget.service.sendPasswordReset(email);
      if (context.mounted) {
        _snack(context, 'Password reset email sent.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to send reset: $e', isError: true);
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, AdminUserModel user) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete ${user.name.isEmpty ? user.email : user.name}?',
      'This removes the Auth account and profile.',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.service.deleteManagedUser(user.id);
      if (context.mounted) {
        _snack(context, 'Account deleted.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Failed to delete account: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _AnalyticsSection extends StatelessWidget {
  final FirebaseService service;

  const _AnalyticsSection({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: service.getOrders(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<List<ProductModel>>(
          stream: service.getProducts(),
          builder: (context, productSnapshot) {
            if (orderSnapshot.hasError || productSnapshot.hasError) {
              return const _StateMessage(
                icon: Icons.error_outline,
                title: 'Analytics could not load',
              );
            }
            if (!orderSnapshot.hasData || !productSnapshot.hasData) {
              return const _LoadingPanel();
            }

            final orders = orderSnapshot.data ?? [];
            final products = productSnapshot.data ?? [];
            final revenue = _revenueTotal(orders);
            final averageOrder = orders.isEmpty
                ? 0.0
                : orders.fold<double>(0, (t, o) => t + o.total) / orders.length;
            final statusCounts = _counts(orders.map((order) => order.status));
            final categoryCounts = _counts(
              products.map((product) => product.category),
            );

            return _ScrollPanel(
              children: [
                _SectionHeader(
                  title: 'Sales and Revenue',
                  subtitle:
                      'Totals are calculated from the current order data.',
                ),
                _MetricGrid(
                  metrics: [
                    _Metric(
                      'Total orders',
                      '${orders.length}',
                      Icons.receipt_long_outlined,
                    ),
                    _Metric(
                      'Delivered revenue',
                      _money(revenue),
                      Icons.payments_outlined,
                    ),
                    _Metric(
                      'Average order',
                      _money(averageOrder),
                      Icons.show_chart_outlined,
                    ),
                    _Metric(
                      'Cancelled orders',
                      '${statusCounts['cancelled'] ?? 0}',
                      Icons.cancel_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionHeader(title: 'Orders by Status'),
                _BarList(values: statusCounts),
                const SizedBox(height: 18),
                _SectionHeader(title: 'Menu Items by Category'),
                _BarList(values: categoryCounts),
              ],
            );
          },
        );
      },
    );
  }
}

class _NotificationsSection extends StatefulWidget {
  final FirebaseService service;

  const _NotificationsSection({required this.service});

  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _targetRole = 'all';
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return _ScrollPanel(
      children: [
        _SectionHeader(
          title: 'Notification Controls',
          subtitle: 'Send a push broadcast to users with saved device tokens.',
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 12),
              _DropdownFilter(
                value: _targetRole,
                values: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(value: 'customer', child: Text('Customers')),
                  DropdownMenuItem(value: 'driver', child: Text('Drivers')),
                  DropdownMenuItem(value: 'admin', child: Text('Admins')),
                ],
                onChanged: (value) =>
                    setState(() => _targetRole = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Send notification'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Recent Campaigns'),
        StreamBuilder<List<NotificationCampaignModel>>(
          stream: widget.service.getNotificationCampaigns(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.error_outline,
                title: 'Campaigns could not load',
                subtitle: '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const _LoadingPanel();
            }
            final campaigns = snapshot.data ?? [];
            if (campaigns.isEmpty) {
              return const _StateMessage(
                icon: Icons.campaign_outlined,
                title: 'No notification campaigns yet',
              );
            }
            return Column(
              children: [
                for (final campaign in campaigns)
                  _Panel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.campaign_outlined,
                        color: MyColors.goldAccent,
                      ),
                      title: Text(campaign.title),
                      subtitle: Text(
                        '${campaign.body}\nTarget: ${_label(campaign.targetRole)} - Sent: ${campaign.successCount}/${campaign.tokenCount}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _snack(context, 'Enter a title and message.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await widget.service.sendNotification(
        title: _title.text.trim(),
        body: _body.text.trim(),
        targetRole: _targetRole,
      );
      final data = result.data as Map<Object?, Object?>;
      if (mounted) {
        _title.clear();
        _body.clear();
        _snack(
          context,
          'Notification sent to ${data['successCount'] ?? 0} device(s).',
        );
      }
    } catch (e) {
      if (mounted) {
        _snack(
          context,
          'Failed to send notification: ${_friendlyNotificationError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String _friendlyNotificationError(Object error) {
    final message = error.toString();
    if (message.contains('[firebase_functions/internal]')) {
      return 'The notification service had a server issue. Please try again after the latest Functions update is deployed.';
    }
    if (message.contains('[firebase_functions/permission-denied]')) {
      return 'This account is not allowed to send admin notifications.';
    }
    if (message.contains('[firebase_functions/invalid-argument]')) {
      return 'Please check the title, message, and target audience.';
    }
    if (message.contains('[firebase_functions/unauthenticated]')) {
      return 'Please sign in again before sending notifications.';
    }
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('[firebase_functions/', '')
        .replaceAll(']', '')
        .trim();
  }
}

class _AccessSection extends StatelessWidget {
  final FirebaseService service;

  const _AccessSection({required this.service});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return _ScrollPanel(
      children: [
        _SectionHeader(
          title: 'Admin Access',
          subtitle:
              'Create admin, driver, or customer accounts and recover passwords.',
        ),
        _Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.verified_user_outlined,
              color: MyColors.goldAccent,
            ),
            title: Text(user?.email ?? 'Signed in admin'),
            subtitle: const Text('Current session has admin dashboard access.'),
            trailing: OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DeliveryFeePanel(service: service),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use this for admin registration, driver onboarding, and customer support account creation.',
                style: TextStyle(color: MyColors.secondaryText),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateUserDialog(service: service),
                ),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Create account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryFeePanel extends StatefulWidget {
  final FirebaseService service;

  const _DeliveryFeePanel({required this.service});

  @override
  State<_DeliveryFeePanel> createState() => _DeliveryFeePanelState();
}

class _DeliveryFeePanelState extends State<_DeliveryFeePanel> {
  final _controller = TextEditingController();
  bool _saving = false;
  double? _loadedFee;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettingsModel>(
      stream: widget.service.watchAppSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings != null && settings.deliveryFee != _loadedFee) {
          _loadedFee = settings.deliveryFee;
          _controller.text = settings.deliveryFee.toStringAsFixed(2);
        }

        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Fee',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This fee is used by the customer app when delivery is selected. Collection stays free.',
                style: TextStyle(color: MyColors.secondaryText),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Delivery fee',
                        prefixText: 'R ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final fee = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (fee == null || fee < 0) {
      _snack(context, 'Enter a valid delivery fee.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.updateDeliveryFee(fee);
      if (mounted) {
        _snack(context, 'Delivery fee updated.');
      }
    } catch (e) {
      if (mounted) {
        _snack(
          context,
          'Failed to update delivery fee: ${_friendlyFunctionError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _RestaurantDialog extends StatefulWidget {
  final FirebaseService service;
  final RestaurantModel? restaurant;

  const _RestaurantDialog({required this.service, this.restaurant});

  @override
  State<_RestaurantDialog> createState() => _RestaurantDialogState();
}

class _RestaurantDialogState extends State<_RestaurantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _location;
  late final TextEditingController _imageUrl;
  final _locationService = LocationAddressService();
  late bool _isOpen;
  String? _coordinateAddress;
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _uploading = false;
  bool _detectingLocation = false;

  @override
  void initState() {
    super.initState();
    final restaurant = widget.restaurant;
    _name = TextEditingController(text: restaurant?.name ?? '');
    _phone = TextEditingController(text: restaurant?.phone ?? '');
    _address = TextEditingController(text: restaurant?.address ?? '');
    _location = TextEditingController(text: restaurant?.location ?? '');
    _imageUrl = TextEditingController(text: restaurant?.imageUrl ?? '');
    _latitude = restaurant?.latitude;
    _longitude = restaurant?.longitude;
    _coordinateAddress = _latitude != null && _longitude != null
        ? _address.text.trim()
        : null;
    _address.addListener(_clearCoordinatesIfAddressChanged);
    _isOpen = restaurant?.isOpen ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.restaurant == null ? 'Add Restaurant' : 'Edit Restaurant',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(_name, 'Name'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                _requiredField(_address, 'Address'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _detectingLocation ? null : _detectLocation,
                    icon: _detectingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: Text(
                      _detectingLocation
                          ? 'Detecting restaurant location...'
                          : 'Use current location',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Coordinates: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrl,
                  decoration: InputDecoration(
                    labelText: 'Image URL',
                    suffixIcon: IconButton(
                      tooltip: 'Upload image',
                      onPressed: _uploading ? null : _uploadImage,
                      icon: _uploading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isOpen,
                  title: const Text('Restaurant open'),
                  onChanged: (value) => setState(() => _isOpen = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final url = await widget.service.pickAndUploadImage('restaurants');
      if (url != null && mounted) {
        _imageUrl.text = url;
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Image upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final detected = await _locationService.detectCurrentAddress();
      if (!mounted) return;
      setState(() {
        _coordinateAddress = detected.address.trim();
        _address.text = detected.address;
        _location.text = detected.locationLabel;
        _latitude = detected.latitude;
        _longitude = detected.longitude;
      });
      _snack(context, 'Restaurant location detected.');
    } catch (e) {
      if (mounted) {
        _snack(context, 'Location detection failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  void _clearCoordinatesIfAddressChanged() {
    if (_coordinateAddress == null) return;
    if (_address.text.trim() == _coordinateAddress) return;
    if (!mounted) return;
    setState(() {
      _coordinateAddress = null;
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'location': _location.text.trim(),
      'imageUrl': _imageUrl.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'geoPoint': _latitude != null && _longitude != null
          ? GeoPoint(_latitude!, _longitude!)
          : null,
      'isOpen': _isOpen,
    };
    try {
      if (widget.restaurant == null) {
        await widget.service.createRestaurant(data);
      } else {
        await widget.service.updateRestaurant(widget.restaurant!.id, data);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to save restaurant: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.removeListener(_clearCoordinatesIfAddressChanged);
    _address.dispose();
    _location.dispose();
    _imageUrl.dispose();
    super.dispose();
  }
}

class _MenuCategoryManager extends StatefulWidget {
  final FirebaseService service;
  final List<MenuCategoryModel> categories;
  final List<ProductModel> products;

  const _MenuCategoryManager({
    required this.service,
    required this.categories,
    required this.products,
  });

  @override
  State<_MenuCategoryManager> createState() => _MenuCategoryManagerState();
}

class _MenuCategoryManagerState extends State<_MenuCategoryManager> {
  final _name = TextEditingController();
  final _sortOrder = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final nextOrder = categories.isEmpty
        ? 1
        : categories.map((item) => item.sortOrder).reduce(max) + 1;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Menu Categories',
            subtitle: 'Create categories once, then select them on menu items.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Category name'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Order',
                    hintText: '$nextOrder',
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _add(nextOrder),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_outlined),
                label: const Text('Add category'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const _StateMessage(
              icon: Icons.category_outlined,
              title: 'No categories added yet',
              subtitle:
                  'Add categories such as Meals, Drinks, Sides, Specials.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  InputChip(
                    avatar: CircleAvatar(child: Text('${category.sortOrder}')),
                    label: Text(category.name),
                    selected: category.active,
                    onPressed: () => _edit(category),
                    onDeleted: () => _delete(category),
                    deleteIcon: const Icon(Icons.delete_outline),
                    tooltip: category.active
                        ? 'Active category'
                        : 'Inactive category',
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _add(int nextOrder) async {
    final name = _name.text.trim();
    final order = int.tryParse(_sortOrder.text.trim()) ?? nextOrder;
    if (name.isEmpty) {
      _snack(context, 'Enter a category name.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createMenuCategory(name: name, sortOrder: order);
      _name.clear();
      _sortOrder.clear();
      if (mounted) {
        _snack(context, 'Category added.');
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to add category: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _edit(MenuCategoryModel category) async {
    final saved = await showDialog<MenuCategoryModel>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (saved == null) return;
    try {
      await widget.service.updateMenuCategory(saved);
      if (mounted) {
        _snack(context, 'Category updated.');
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to update category: $e', isError: true);
      }
    }
  }

  Future<void> _delete(MenuCategoryModel category) async {
    final inUse = widget.products.any(
      (product) =>
          product.category.trim().toLowerCase() ==
          category.name.trim().toLowerCase(),
    );
    if (inUse) {
      _snack(
        context,
        'This category is used by menu items. Move those items first.',
        isError: true,
      );
      return;
    }
    final confirmed = await _confirmDelete(
      context,
      'Delete ${category.name}?',
      'This removes the category from the selectable list.',
    );
    if (confirmed != true) return;
    try {
      await widget.service.deleteMenuCategory(category.id);
      if (mounted) {
        _snack(context, 'Category deleted.');
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to delete category: $e', isError: true);
      }
    }
  }
}

class _CategoryDialog extends StatefulWidget {
  final MenuCategoryModel category;

  const _CategoryDialog({required this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _sortOrder;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category.name);
    _sortOrder = TextEditingController(
      text: widget.category.sortOrder.toString(),
    );
    _active = widget.category.active;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sortOrder,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Order'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            title: const Text('Active'),
            onChanged: (value) => setState(() => _active = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              MenuCategoryModel(
                id: widget.category.id,
                name: name,
                sortOrder:
                    int.tryParse(_sortOrder.text.trim()) ??
                    widget.category.sortOrder,
                active: _active,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _sortOrder.dispose();
    super.dispose();
  }
}

class _ProductDialog extends StatefulWidget {
  final FirebaseService service;
  final List<RestaurantModel> restaurants;
  final List<String> categories;
  final ProductModel? product;

  const _ProductDialog({
    required this.service,
    required this.restaurants,
    required this.categories,
    this.product,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _imageUrl;
  late String _restaurantId;
  late String _category;
  late bool _available;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _restaurantId = product?.restaurantId ?? widget.restaurants.first.id;
    _category = widget.categories.contains(product?.category)
        ? product!.category
        : widget.categories.first;
    _available = product?.available ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _restaurantId,
                  decoration: const InputDecoration(labelText: 'Restaurant'),
                  items: [
                    for (final restaurant in widget.restaurants)
                      DropdownMenuItem(
                        value: restaurant.id,
                        child: Text(restaurant.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _restaurantId = value ?? _restaurantId),
                ),
                const SizedBox(height: 10),
                _requiredField(_name, 'Name'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final price = double.tryParse(value ?? '');
                    if (price == null || price < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _imageUrl,
                  decoration: InputDecoration(
                    labelText: 'Image URL',
                    suffixIcon: IconButton(
                      tooltip: 'Upload image',
                      onPressed: _uploading ? null : _uploadImage,
                      icon: _uploading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _available,
                  title: const Text('Available'),
                  onChanged: (value) => setState(() => _available = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final url = await widget.service.pickAndUploadImage('products');
      if (url != null && mounted) {
        _imageUrl.text = url;
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Image upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final data = {
      'restaurantId': _restaurantId,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': double.parse(_price.text.trim()),
      'category': _category,
      'imageUrl': _imageUrl.text.trim(),
      'available': _available,
    };
    try {
      if (widget.product == null) {
        await widget.service.createProduct(data);
      } else {
        await widget.service.updateProduct(widget.product!.id, data);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to save item: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _imageUrl.dispose();
    super.dispose();
  }
}

class _CreateUserDialog extends StatefulWidget {
  final FirebaseService service;
  final String? role;

  const _CreateUserDialog({required this.service, this.role});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late String _role;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _role = widget.role ?? 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Account'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(_name, 'Name'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty ||
                        !(value ?? '').contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Use at least 6 characters';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final role in _roles)
                      DropdownMenuItem(value: role, child: Text(_label(role))),
                  ],
                  onChanged: widget.role == null
                      ? (value) => setState(() => _role = value ?? _role)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createManagedUser(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
        role: _role,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _snack(
          context,
          'Failed to create account: ${_friendlyFunctionError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }
}

class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RestaurantCard({
    required this.restaurant,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _ImageThumb(url: restaurant.imageUrl, icon: Icons.storefront),
        title: Text(restaurant.name),
        subtitle: Text('${restaurant.address}\n${restaurant.phone}'),
        isThreeLine: true,
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(value: restaurant.isOpen, onChanged: onToggle),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final String restaurantName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.restaurantName,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _ImageThumb(url: product.imageUrl, icon: Icons.fastfood),
        title: Text(product.name),
        subtitle: Text(
          '$restaurantName - ${product.category} - ${_money(product.price)}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(product.available ? 'In stock' : 'Out'),
            Switch(value: product.available, onChanged: onToggle),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final String restaurantName;
  final AdminUserModel? customer;
  final List<AdminUserModel> drivers;
  final Future<void> Function({
    String? status,
    String? paymentStatus,
    String? driverId,
  })
  onUpdate;

  const _OrderCard({
    required this.order,
    required this.restaurantName,
    required this.customer,
    required this.drivers,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final driverValue = order.driverId ?? '';
    final isCollection = order.fulfillmentType == 'collection';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Order ${order.orderNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _StatusChip(label: _label(order.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${customer?.name ?? 'Unknown customer'} - $restaurantName',
            style: const TextStyle(color: MyColors.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.items.length} item(s) - ${isCollection ? 'Collection' : order.deliveryAddress}',
            style: const TextStyle(color: MyColors.secondaryText),
          ),
          const SizedBox(height: 12),
          if (isCollection) ...[
            _CollectionTypePanel(collectionType: order.collectionType),
            const SizedBox(height: 12),
          ],
          if (order.restaurantNote.trim().isNotEmpty) ...[
            _RestaurantNotePanel(note: order.restaurantNote),
            const SizedBox(height: 12),
          ],
          _OrderItemsBreakdown(items: order.items),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DropdownFilter(
                value: order.status,
                values: [
                  for (final status in _orderStatuses)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_label(status)),
                    ),
                ],
                onChanged: (value) => onUpdate(status: value),
              ),
              _DropdownFilter(
                value: order.paymentStatus,
                values: [
                  for (final status in _paymentStatuses)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_label(status)),
                    ),
                ],
                onChanged: (value) => onUpdate(paymentStatus: value),
              ),
              if (isCollection)
                const Chip(
                  avatar: Icon(Icons.storefront_outlined, size: 18),
                  label: Text('Collection'),
                )
              else
                _DropdownFilter(
                  value: drivers.any((driver) => driver.id == driverValue)
                      ? driverValue
                      : '',
                  values: [
                    const DropdownMenuItem(value: '', child: Text('No driver')),
                    for (final driver in drivers)
                      DropdownMenuItem(
                        value: driver.id,
                        child: Text(
                          driver.name.isEmpty ? driver.email : driver.name,
                        ),
                      ),
                  ],
                  onChanged: (value) => onUpdate(driverId: value ?? ''),
                ),
              Chip(label: Text(_money(order.total))),
              if (!isCollection && order.routeDistanceMeters != null)
                Chip(
                  avatar: const Icon(Icons.route_outlined, size: 18),
                  label: Text(
                    '${(order.routeDistanceMeters! / 1000).toStringAsFixed(1)} km road',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionTypePanel extends StatelessWidget {
  final String collectionType;

  const _CollectionTypePanel({required this.collectionType});

  @override
  Widget build(BuildContext context) {
    final eatIn = collectionType == 'eat_in';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.goldAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MyColors.goldAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            eatIn ? Icons.restaurant_outlined : Icons.shopping_bag_outlined,
            color: MyColors.goldAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eatIn ? 'Customer will eat at the restaurant' : 'Take away order',
              style: const TextStyle(
                color: MyColors.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantNotePanel extends StatelessWidget {
  final String note;

  const _RestaurantNotePanel({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MyColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined, color: MyColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer note for restaurant',
                  style: TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.trim(),
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _OrderItemsBreakdown({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MyColors.elevatedSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MyColors.divider),
        ),
        child: const Text(
          'No item details saved for this order.',
          style: TextStyle(color: MyColors.secondaryText),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MyColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_menu, size: 18, color: MyColors.goldAccent),
              SizedBox(width: 8),
              Text(
                'Customer ordered',
                style: TextStyle(
                  color: MyColors.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _OrderItemRow(item: item)),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = _itemName(item);
    final quantity = _itemQuantity(item);
    final price = _itemPrice(item);
    final lineTotal = quantity * price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MyColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${quantity}x',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MyColors.goldAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'R${price.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    color: MyColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'R${lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _itemName(Map<String, dynamic> item) {
    final value = item['name'] ?? item['productName'] ?? item['title'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Menu item' : text;
  }

  static int _itemQuantity(Map<String, dynamic> item) {
    final value = item['quantity'] ?? item['qty'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  static double _itemPrice(Map<String, dynamic> item) {
    final value = item['price'] ?? item['unitPrice'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _UserCard extends StatelessWidget {
  final AdminUserModel user;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onRoleChanged,
    required this.onReset,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: MyColors.primary,
          child: Text(
            (user.name.isEmpty ? user.email : user.name).characters
                .take(1)
                .toString()
                .toUpperCase(),
          ),
        ),
        title: Text(user.name.isEmpty ? user.email : user.name),
        subtitle: Text('${user.email}\n${user.phone}'),
        isThreeLine: true,
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            _DropdownFilter(
              value: user.role,
              values: [
                for (final role in _roles)
                  DropdownMenuItem(value: role, child: Text(_label(role))),
              ],
              onChanged: (value) {
                if (value != null && value != user.role) {
                  onRoleChanged(value);
                }
              },
            ),
            IconButton(
              tooltip: 'Send password reset',
              onPressed: onReset,
              icon: const Icon(Icons.lock_reset_outlined),
            ),
            IconButton(
              tooltip: 'Delete account',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 620
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 4.5 : 3.2,
          children: [
            for (final metric in metrics)
              _Panel(
                child: Row(
                  children: [
                    Icon(metric.icon, color: MyColors.goldAccent, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            metric.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            metric.label,
                            style: const TextStyle(
                              color: MyColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);
}

class _AttentionList extends StatelessWidget {
  final List<ProductModel> products;
  final List<OrderModel> orders;
  final List<RestaurantModel> restaurants;

  const _AttentionList({
    required this.products,
    required this.orders,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    final closedRestaurants = restaurants
        .where((item) => !item.isOpen)
        .toList();
    final outOfStock = products.where((item) => !item.available).toList();
    final pendingOrders = orders
        .where((item) => item.status == 'pending')
        .toList();

    return Column(
      children: [
        _AttentionTile(
          icon: Icons.storefront_outlined,
          label: 'Closed restaurants',
          value: '${closedRestaurants.length}',
        ),
        _AttentionTile(
          icon: Icons.inventory_2_outlined,
          label: 'Out-of-stock menu items',
          value: '${outOfStock.length}',
        ),
        _AttentionTile(
          icon: Icons.receipt_long_outlined,
          label: 'Pending orders',
          value: '${pendingOrders.length}',
        ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AttentionTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: MyColors.goldAccent),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _BarList extends StatelessWidget {
  final Map<String, int> values;

  const _BarList({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (values.isEmpty) {
      return const _StateMessage(
        icon: Icons.bar_chart_outlined,
        title: 'No data yet',
      );
    }
    return Column(
      children: [
        for (final entry in values.entries)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_label(entry.key))),
                    Text('${entry.value}'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: maxValue == 0 ? 0 : entry.value / maxValue,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _Toolbar({
    required this.title,
    required this.child,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (actionLabel != null && actionIcon != null)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> values;
  final ValueChanged<String?>? onChanged;

  const _DropdownFilter({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: values,
        onChanged: onChanged,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String url;
  final IconData icon;

  const _ImageThumb({required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(
        backgroundColor: MyColors.elevatedSurface,
        child: Icon(icon, color: MyColors.goldAccent),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          backgroundColor: MyColors.elevatedSurface,
          child: Icon(icon, color: MyColors.goldAccent),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      side: BorderSide.none,
      backgroundColor: MyColors.primary.withValues(alpha: 0.35),
      label: Text(label),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrollPanel extends StatelessWidget {
  final List<Widget> children;

  const _ScrollPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MyColors.divider),
      ),
      child: child,
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: MyColors.primary),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _StateMessage({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MyColors.goldAccent, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MyColors.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

TextFormField _requiredField(TextEditingController controller, String label) {
  return TextFormField(
    controller: controller,
    validator: (value) {
      if ((value ?? '').trim().isEmpty) {
        return '$label is required';
      }
      return null;
    },
    decoration: InputDecoration(labelText: label),
  );
}

Future<bool?> _confirmDelete(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? MyColors.error : MyColors.success,
    ),
  );
}

String _friendlyFunctionError(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    if (error.code == 'permission-denied') {
      return 'Only admins can do this.';
    }
    if (error.code == 'unauthenticated') {
      return 'Please sign in again.';
    }
    return 'Server issue. Please try again.';
  }

  final message = error.toString();
  if (message.contains('cloud_functions') ||
      message.contains('CloudFunctionsHostApi') ||
      message.contains('\n#0')) {
    return 'Server issue. Please try again.';
  }
  return message.replaceFirst('Exception: ', '').trim();
}

bool _hasError(List<AsyncSnapshot<dynamic>> snapshots) {
  return snapshots.any((snapshot) => snapshot.hasError);
}

bool _hasData(List<AsyncSnapshot<dynamic>> snapshots) {
  return snapshots.every((snapshot) => snapshot.hasData);
}

String _money(double amount) {
  return 'R${amount.toStringAsFixed(2)}';
}

String _label(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

double _revenueTotal(List<OrderModel> orders) {
  return orders
      .where(
        (order) =>
            order.status == 'delivered' ||
            order.paymentStatus == 'paid' ||
            order.paymentStatus == 'completed',
      )
      .fold<double>(0, (total, order) => total + order.total);
}

Map<String, int> _counts(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    final key = value.trim().isEmpty ? 'Uncategorised' : value;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
