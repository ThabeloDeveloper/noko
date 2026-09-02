import 'package:cloud_firestore/cloud_firestore.dart';

class MenuCategoryModel {
  final String id;
  final String name;
  final int sortOrder;
  final bool active;

  const MenuCategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'sortOrder': sortOrder, 'active': active};
  }

  factory MenuCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MenuCategoryModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      sortOrder: _toInt(data['sortOrder']),
      active: data['active'] != false,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
