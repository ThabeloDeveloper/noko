import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/data/models/driver_message.dart';
import 'package:noko_driver/data/services/firebase_service.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String title;

  const ChatPage({super.key, required this.receiverId, required this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _service = FirebaseService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _service.markMessagesRead(userId: _uid, otherId: widget.receiverId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _service.sendMessage(
      DriverMessage(
        id: '',
        senderId: _uid,
        receiverId: widget.receiverId,
        text: text,
        timestamp: DateTime.now(),
      ),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: MyColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DriverMessage>>(
              stream: _service.watchMessages(_uid, widget.receiverId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                _service.markMessagesRead(
                  userId: _uid,
                  otherId: widget.receiverId,
                );
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: MyColors.secondaryText),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message.senderId == _uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine ? MyColors.primary : MyColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.text,
                              style: const TextStyle(
                                color: MyColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mine
                                  ? message.readAt == null
                                        ? 'sent'
                                        : 'read'
                                  : '',
                              style: const TextStyle(
                                color: MyColors.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: MyColors.surfaceCard,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Message customer...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: MyColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
