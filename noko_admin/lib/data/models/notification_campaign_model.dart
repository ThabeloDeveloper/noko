import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationCampaignModel {
  final String id;
  final String title;
  final String body;
  final String targetRole;
  final int tokenCount;
  final int successCount;
  final int failureCount;
  final DateTime createdAt;

  const NotificationCampaignModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetRole,
    required this.tokenCount,
    required this.successCount,
    required this.failureCount,
    required this.createdAt,
  });

  factory NotificationCampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NotificationCampaignModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      targetRole: data['targetRole'] ?? 'all',
      tokenCount: _toInt(data['tokenCount']),
      successCount: _toInt(data['successCount']),
      failureCount: _toInt(data['failureCount']),
      createdAt: _toDate(data['createdAt']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
