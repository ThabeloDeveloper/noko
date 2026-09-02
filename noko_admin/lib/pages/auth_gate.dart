import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'admin_home.dart';

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const _AdminSignInPage();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final role = roleSnapshot.data?.data()?['role'];
            if (role != 'admin') {
              return const _AccessDeniedPage();
            }

            return const AdminHome();
          },
        );
      },
    );
  }
}

class _AdminSignInPage extends StatefulWidget {
  const _AdminSignInPage();

  @override
  State<_AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends State<_AdminSignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscured = true;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Enter your admin email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign in failed.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: MyColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: MyColors.primary,
                  size: 72,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Admin Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MyColors.primaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: MyColors.primaryText),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: MyColors.secondaryText),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: MyColors.primary,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscured,
                  style: const TextStyle(color: MyColors.primaryText),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: MyColors.secondaryText),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: MyColors.primary,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _isObscured = !_isObscured),
                      icon: Icon(
                        _isObscured ? Icons.visibility : Icons.visibility_off,
                        color: MyColors.primary,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.buttonPrimary,
                    foregroundColor: MyColors.buttonPrimaryText,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: MyColors.error, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Admin access required',
                style: TextStyle(
                  color: MyColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MyColors.background,
      body: Center(child: CircularProgressIndicator(color: MyColors.primary)),
    );
  }
}
