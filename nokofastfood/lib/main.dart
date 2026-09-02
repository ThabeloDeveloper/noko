import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/providers/cart_provider.dart';
import 'package:nokofastfood/data/services/notification_service.dart';
import 'package:nokofastfood/firebase_options.dart';
import 'package:nokofastfood/pages/home_page.dart';
import 'package:nokofastfood/pages/landing.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseInitialization = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  unawaited(
    firebaseInitialization
        .then((_) => _initializeOptionalServices())
        .catchError((_) {}),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()..loadCart()),
      ],
      child: MyApp(firebaseInitialization: firebaseInitialization),
    ),
  );
}

Future<void> _initializeOptionalServices() async {
  await GoogleSignIn.instance
      .initialize(
        serverClientId:
            "823795709540-j7p91cg5rvo70muvs5al3v3nokg1tsrl.apps.googleusercontent.com",
      )
      .catchError((_) {});
  await NotificationService().initialize().catchError((_) {});
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> firebaseInitialization;

  const MyApp({super.key, required this.firebaseInitialization});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noko Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: MyColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MyColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<FirebaseApp>(
        future: firebaseInitialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _StartupScreen(
              message: 'Could not start the app. Please try again.',
            );
          }

          if (snapshot.connectionState == ConnectionState.done) {
            return const _AuthGate();
          }

          return const _StartupScreen();
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FirebaseAuth.instance.currentUser == null
        ? const Landing()
        : const HomePage();
  }
}

class _StartupScreen extends StatelessWidget {
  final String message;

  const _StartupScreen({this.message = 'Starting Noko Fast Food...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: MyColors.primary),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
