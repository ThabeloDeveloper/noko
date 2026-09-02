import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants/colors.dart';
import 'firebase_options.dart';
import 'pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NokoAdminApp());
}

class NokoAdminApp extends StatelessWidget {
  const NokoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noko Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: MyColors.primary,
        scaffoldBackgroundColor: MyColors.background,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: MyColors.primary,
          secondary: MyColors.goldAccent,
          surface: MyColors.surfaceCard,
          error: MyColors.error,
        ),
        useMaterial3: true,
      ),
      home: const AdminAuthGate(),
    );
  }
}
