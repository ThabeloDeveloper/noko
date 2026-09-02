import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

class AdminStockPage extends StatefulWidget {
  const AdminStockPage({super.key});

  @override
  State<AdminStockPage> createState() => _AdminStockPageState();
}

class _AdminStockPageState extends State<AdminStockPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text(
          'Stock Management',
          style: TextStyle(
            color: MyColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSectionHeader("Restaurant Status")),
          _buildRestaurantStatusList(),
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(
                color: MyColors.divider,
                thickness: 1,
                indent: 16,
                endIndent: 16,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSectionHeader("Product Availability"),
          ),
          _buildProductAvailabilityList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: MyColors.goldAccent,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRestaurantStatusList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('restaurants').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: MyColors.error),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: MyColors.primary),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No restaurants found.",
                style: TextStyle(color: MyColors.secondaryText),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool isOpen = data['isOpen'] ?? false;
            final String name = data['name'] ?? 'Unknown Restaurant';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: MyColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isOpen ? "RESTAURANT OPEN" : "RESTAURANT CLOSED",
                  style: TextStyle(
                    color: isOpen ? MyColors.success : MyColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Switch(
                  value: isOpen,
                  activeThumbColor: MyColors.success,
                  activeTrackColor: MyColors.success.withValues(alpha: 0.3),
                  inactiveThumbColor: MyColors.secondaryText,
                  inactiveTrackColor: MyColors.divider,
                  onChanged: (value) => _updateRestaurantStatus(doc.id, value),
                ),
              ),
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Widget _buildProductAvailabilityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: MyColors.error),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: MyColors.primary),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No products found.",
                style: TextStyle(color: MyColors.secondaryText),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool available = data['available'] ?? false;
            final String name = data['name'] ?? 'Unknown Product';
            final String category = data['category'] ?? 'General';
            final String price = (data['price'] ?? 0.0).toStringAsFixed(2);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: MyColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  "$category - R$price",
                  style: const TextStyle(
                    color: MyColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      available ? "In Stock" : "Out of Stock",
                      style: TextStyle(
                        color: available
                            ? MyColors.success.withValues(alpha: 0.8)
                            : MyColors.error.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: available,
                      activeThumbColor: MyColors.primary,
                      activeTrackColor: MyColors.primary.withValues(alpha: 0.3),
                      inactiveThumbColor: MyColors.secondaryText,
                      inactiveTrackColor: MyColors.divider,
                      onChanged: (value) =>
                          _updateProductAvailability(doc.id, value),
                    ),
                  ],
                ),
              ),
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Future<void> _updateRestaurantStatus(String id, bool isOpen) async {
    try {
      await _firestore.collection('restaurants').doc(id).update({
        'isOpen': isOpen,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update restaurant: $e"),
            backgroundColor: MyColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateProductAvailability(String id, bool available) async {
    try {
      await _firestore.collection('products').doc(id).update({
        'available': available,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update product: $e"),
            backgroundColor: MyColors.error,
          ),
        );
      }
    }
  }
}
