import 'package:cloud_firestore/cloud_firestore.dart';

class DriverMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final DateTime? readAt;

  const DriverMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.readAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    };
  }

  factory DriverMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return DriverMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      readAt: data['readAt'] is Timestamp
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }
}
