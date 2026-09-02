import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/message_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String title;

  const ChatPage({super.key, required this.receiverId, this.title = 'Chat'});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _firebaseService.markMessagesRead(
      userId: _currentUserId,
      otherId: widget.receiverId,
    );
  }

  Future<void> _sendMessage({String attachmentUrl = ''}) async {
    if (_messageController.text.trim().isEmpty && attachmentUrl.isEmpty) {
      return;
    }

    final message = MessageModel(
      id: '', // Firestore will generate an ID
      senderId: _currentUserId,
      receiverId: widget.receiverId,
      text: _messageController.text.trim(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentUrl.isEmpty ? '' : 'image',
      timestamp: DateTime.now(),
    );

    await _firebaseService.sendMessage(message);
    _messageController.clear();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await _firebaseService.uploadChatImage(
        uid: _currentUserId,
        file: File(picked.path),
      );
      await _sendMessage(attachmentUrl: url);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: MyColors.primaryText),
        ),
        backgroundColor: MyColors.background,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _firebaseService.getMessages(
                _currentUserId,
                widget.receiverId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                _firebaseService.markMessagesRead(
                  userId: _currentUserId,
                  otherId: widget.receiverId,
                );
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: MyColors.secondaryText),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? MyColors.primary : MyColors.elevatedSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(color: MyColors.primaryText, fontSize: 16),
            ),
            if (message.attachmentUrl.isNotEmpty) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.attachmentUrl,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Image could not load',
                      style: TextStyle(color: MyColors.secondaryText),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}${isMe
                  ? message.readAt == null
                        ? ' - sent'
                        : ' - read'
                  : ''}',
              style: const TextStyle(
                color: MyColors.secondaryText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: MyColors.surfaceCard,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach image',
            onPressed: _uploading ? null : _pickImage,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined, color: MyColors.goldAccent),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: MyColors.primaryText),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: MyColors.secondaryText),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: MyColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _sendMessage(),
            icon: const Icon(Icons.send, color: MyColors.goldAccent),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
