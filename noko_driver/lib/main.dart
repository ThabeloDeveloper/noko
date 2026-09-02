import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/firebase_options.dart';
import 'package:noko_driver/pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noko Driver',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: MyColors.primary,
        scaffoldBackgroundColor: MyColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MyColors.primary,
          brightness: Brightness.dark,
          surface: MyColors.surfaceCard,
        ),
      ),
      home: const DriverAuthGate(),
    );
  }
}
