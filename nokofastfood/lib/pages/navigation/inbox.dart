import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/message_model.dart';
import 'package:nokofastfood/data/models/restaurant_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/pages/chat_page.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  final FirebaseService _firebaseService = FirebaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: MyColors.background,
        body: Center(
          child: Text(
            'Please log in to view messages',
            style: TextStyle(color: MyColors.primaryText),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inbox',
          style: TextStyle(color: MyColors.primaryText),
        ),
        backgroundColor: MyColors.background,
        elevation: 0,
      ),
      backgroundColor: MyColors.background,
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _firebaseService.getRestaurants(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: MyColors.primary),
            );
          }
          final restaurants = snapshot.data ?? [];
          if (restaurants.isEmpty) {
            return const Center(
              child: Text(
                'No restaurants available',
                style: TextStyle(color: MyColors.secondaryText),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              return _buildChatItem(restaurants[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(RestaurantModel restaurant) {
    return Card(
      color: MyColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: MyColors.primary,
          foregroundImage: restaurant.imageUrl.isEmpty
              ? null
              : NetworkImage(restaurant.imageUrl),
          child: restaurant.imageUrl.isEmpty
              ? const Icon(Icons.restaurant, color: MyColors.primaryText)
              : null,
        ),
        title: Text(
          restaurant.name,
          style: const TextStyle(
            color: MyColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: StreamBuilder<List<MessageModel>>(
          stream: _firebaseService.getMessages(_currentUserId, restaurant.id),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final lastMessage = snapshot.data!.last;
              final waitingForRestaurant =
                  lastMessage.senderId == _currentUserId &&
                  lastMessage.readAt == null;
              return Text(
                waitingForRestaurant
                    ? 'Waiting for restaurant'
                    : lastMessage.senderId == restaurant.id
                    ? 'Restaurant replied: ${lastMessage.text}'
                    : lastMessage.text.isEmpty
                    ? 'Image sent'
                    : lastMessage.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MyColors.secondaryText),
              );
            }
            return Text(
              restaurant.isOpen ? 'Connect with this restaurant' : 'Closed now',
              style: const TextStyle(color: MyColors.secondaryText),
            );
          },
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: MyColors.secondaryText,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverId: restaurant.id,
                title: 'Chat with ${restaurant.name}',
              ),
            ),
          );
        },
      ),
    );
  }
}
