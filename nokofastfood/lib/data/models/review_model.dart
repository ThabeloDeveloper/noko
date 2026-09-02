import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String productId;
  final String customerId;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ReviewModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Customer',
      rating: (data['rating'] ?? 0).toInt(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
