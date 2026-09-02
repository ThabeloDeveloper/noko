import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String attachmentUrl;
  final String attachmentType;
  final DateTime timestamp;
  final DateTime? readAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.attachmentUrl = '',
    this.attachmentType = '',
    required this.timestamp,
    this.readAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'timestamp': Timestamp.fromDate(timestamp),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    };
  }

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      attachmentUrl: data['attachmentUrl'] ?? '',
      attachmentType: data['attachmentType'] ?? '',
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      readAt: data['readAt'] is Timestamp
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }
}
