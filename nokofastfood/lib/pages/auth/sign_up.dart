import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/constants/loading.dart';
import 'package:nokofastfood/data/models/user_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/pages/home_page.dart';
import 'package:nokofastfood/pages/auth/sign_in.dart';
import 'package:nokofastfood/pages/legal_page.dart';

import '../../constants/bottom_alert.dart';
import 'phone_auth_sheet.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var nameController = TextEditingController();
  var phoneController = TextEditingController();

  var isObscured = true;
  FirebaseAuth auth = FirebaseAuth.instance;

  bool isLoading = false;

  Future<void> _syncPhoneUserToFirestore(User? user) async {
    if (user == null) return;

    final existingUser = await FirebaseService().getUser(user.uid);
    if (existingUser != null) return;

    await FirebaseService().createUser(
      UserModel(
        id: user.uid,
        name: nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : (user.displayName ?? ''),
        phone: user.phoneNumber ?? phoneController.text.trim(),
        email: user.email ?? emailController.text.trim(),
        role: 'customer',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> signUpWithPhone() async {
    try {
      final userCredential = await showPhoneAuthSheet(context);
      if (!mounted || userCredential?.user == null) return;
      setState(() {
        isLoading = true;
      });
      await _syncPhoneUserToFirestore(userCredential!.user);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Phone sign up failed', e.toString(), BottomAlertType.error);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void createUser(BuildContext context) async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Missing name',
        'Please enter your name.',
        BottomAlertType.error,
      );
    } else if (phone.isEmpty) {
      _showMessage(
        'Missing phone number',
        'Please enter your phone number.',
        BottomAlertType.error,
      );
    } else if (email.isEmpty) {
      _showMessage(
        'Missing email',
        'Please enter your email address.',
        BottomAlertType.error,
      );
    } else if (password.isEmpty) {
      _showMessage(
        'Missing password',
        'Please enter your password.',
        BottomAlertType.error,
      );
    } else if (password.length < 8) {
      _showMessage(
        'Password too short',
        'Please enter minimum of 8 characters.',
        BottomAlertType.error,
      );
    } else {
      setState(() {
        isLoading = true;
      });
      try {
        final UserCredential credential = await auth
            .createUserWithEmailAndPassword(email: email, password: password);

        if (credential.user != null) {
          final userModel = UserModel(
            id: credential.user!.uid,
            name: name,
            phone: phone,
            email: email,
            role: 'customer',
            createdAt: DateTime.now(),
          );

          await FirebaseService().createUser(userModel);

          if (!credential.user!.emailVerified) {
            await credential.user!.sendEmailVerification();
            if (!context.mounted) return;
            showModalBottomSheet(
              isDismissible: true,
              context: context,
              builder: (builder) => const BottomAlert(
                title: "Verify",
                message:
                    "A message has been sent to your email, please verify your email and sign in again.",
                type: BottomAlertType.info,
              ),
            );
            await auth.signOut();
          }
        }
        if (!context.mounted) return;
        setState(() {
          isLoading = false;
        });
      } on FirebaseAuthException catch (e) {
        if (!context.mounted) return;
        setState(() {
          isLoading = false;
        });
        _showMessage(
          'Sign up failed',
          e.message ?? "An error occurred",
          BottomAlertType.error,
        );
      } catch (e) {
        if (!context.mounted) return;
        setState(() {
          isLoading = false;
        });
        _showMessage('Sign up failed', e.toString(), BottomAlertType.error);
      }
    }
  }

  void _showMessage(String title, String message, BottomAlertType type) {
    if (!mounted) return;
    showAppBottomMessage(context, title: title, message: message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    SizedBox(height: 30),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 24,
                          color: MyColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Text(
                        "Please fill in your information to get started.",
                        style: TextStyle(
                          color: MyColors.secondaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 10,
                      ),
                      child: TextField(
                        controller: nameController,
                        keyboardType: TextInputType.name,
                        style: TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person,
                            color: MyColors.primary,
                          ),
                          hintText: "Full Name",
                          hintStyle: TextStyle(
                            color: MyColors.secondaryText,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 5,
                      ),
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.phone,
                            color: MyColors.primary,
                          ),
                          hintText: "Phone Number",
                          hintStyle: TextStyle(
                            color: MyColors.secondaryText,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 5,
                      ),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.email,
                            color: MyColors.primary,
                          ),
                          hintText: "johndoe@example.com",
                          hintStyle: TextStyle(
                            color: MyColors.secondaryText,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30.0,
                        vertical: 5,
                      ),
                      child: TextField(
                        controller: passwordController,
                        keyboardType: TextInputType.text,
                        obscureText: isObscured,
                        style: TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                isObscured = !isObscured;
                              });
                            },
                            icon: Icon(
                              color: MyColors.primary,
                              isObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                          prefixIcon: Icon(Icons.lock, color: MyColors.primary),
                          hintText: "*********",
                          hintStyle: TextStyle(
                            color: MyColors.secondaryText,
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Row(
                        children: [
                          Text(
                            "Already have an account?",
                            style: TextStyle(color: MyColors.primaryText),
                          ),
                          SizedBox(width: 3),
                          InkWell(
                            onTap: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                CupertinoPageRoute(
                                  builder: (builder) => SignIn(),
                                ),
                                (predicate) => false,
                              );
                            },
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                color: MyColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),
                    InkWell(
                      splashColor: Colors.transparent,
                      onTap: () {
                        createUser(context);
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        width: MediaQuery.sizeOf(context).width,
                        height: 50,
                        decoration: BoxDecoration(
                          color: MyColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: MyColors.buttonPrimaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(color: MyColors.secondaryText),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(color: MyColors.secondaryText),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: MyColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    InkWell(
                      splashColor: Colors.transparent,
                      onTap: signUpWithPhone,
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        width: MediaQuery.sizeOf(context).width,
                        height: 50,
                        decoration: BoxDecoration(
                          color: MyColors.elevatedSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MyColors.primary),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: MyColors.primaryText,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Continue with Phone',
                                style: TextStyle(
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
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LegalPage.terms(),
                            ),
                          ),
                          child: Text(
                            "Terms & Condition",
                            style: TextStyle(
                              color: MyColors.goldAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(width: 3),
                        Text(
                          "and",
                          style: TextStyle(
                            color: MyColors.primaryText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: 3),

                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LegalPage.privacy(),
                            ),
                          ),
                          child: Text(
                            "Privacy Policy",
                            style: TextStyle(
                              color: MyColors.goldAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            isLoading ? Loading() : SizedBox(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
