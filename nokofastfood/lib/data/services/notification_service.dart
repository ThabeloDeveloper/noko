import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_service.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> initialize() async {
    await _messaging.requestPermission();
    await _syncCurrentToken();

    _auth.authStateChanges().listen((_) {
      _syncCurrentToken();
    });

    _messaging.onTokenRefresh.listen((token) {
      final user = _auth.currentUser;
      if (user != null) {
        _firebaseService.updateUserMessagingToken(user.uid, token);
      }
    });
  }

  Future<void> _syncCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _firebaseService.updateUserMessagingToken(user.uid, token);
    }
  }
}
