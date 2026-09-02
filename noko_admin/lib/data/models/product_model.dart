import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool available;

  ProductModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.available,
  });

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'available': available,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductModel(
      id: documentId,
      restaurantId: map['restaurantId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      available: map['available'] ?? false,
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel.fromMap(data, doc.id);
  }
}
