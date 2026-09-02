import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:nokofastfood/constants/loading.dart';
import 'package:nokofastfood/pages/home_page.dart';
import 'package:nokofastfood/pages/auth/sign_up.dart';
import 'package:nokofastfood/pages/legal_page.dart';

import '../../constants/colors.dart';
import '../../data/models/user_model.dart';
import '../../data/services/firebase_service.dart';
import 'phone_auth_sheet.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  var isObscured = true;
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var isLoading = false;
  final auth = FirebaseAuth.instance;

  void signIn() async {
    if (emailController.text.trim().isEmpty) {
      _showMessage(
        'Missing email',
        'Please enter your email address.',
        BottomAlertType.error,
      );
    } else if (passwordController.text.trim().isEmpty) {
      _showMessage(
        'Missing password',
        'Please enter your password.',
        BottomAlertType.error,
      );
    } else if (passwordController.text.trim().length < 8) {
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
        final UserCredential userCredential = await auth
            .signInWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        if (userCredential.user != null) {
          if (!userCredential.user!.emailVerified) {
            await userCredential.user!.sendEmailVerification();
            if (!mounted) return;
            if (!context.mounted) return;
            showModalBottomSheet(
              isDismissible: true,
              context: context,
              builder: (builder) => const BottomAlert(
                title: "Verify",
                message:
                    "A message has been sent to your email, please verify to continue.",
                type: BottomAlertType.info,
              ),
            );
          } else {
            await _syncUserToFirestore(userCredential.user);
            _goHome();
            return;
          }
        }
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        _showMessage('Sign in failed', e.toString(), BottomAlertType.error);
      }
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          "823795709540-j7p91cg5rvo70muvs5al3v3nokg1tsrl.apps.googleusercontent.com",
    );

    // Trigger the authentication flow
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    final UserCredential userCredential = await FirebaseAuth.instance
        .signInWithCredential(credential);

    await _syncUserToFirestore(userCredential.user);
    _goHome();

    return userCredential;
  }

  Future<void> _syncUserToFirestore(User? user) async {
    if (user != null) {
      final existingUser = await FirebaseService().getUser(user.uid);
      if (existingUser == null) {
        await FirebaseService().createUser(
          UserModel(
            id: user.uid,
            name: user.displayName ?? '',
            phone: user.phoneNumber ?? '',
            email: user.email ?? '',
            role: 'customer',
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      CupertinoPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> signInWithPhone() async {
    final userCredential = await showPhoneAuthSheet(context);
    if (!mounted || userCredential?.user == null) return;
    await _syncUserToFirestore(userCredential!.user);
    _goHome();
  }

  Future<void> _sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(
        'Email needed',
        'Enter your email address first.',
        BottomAlertType.error,
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      await auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMessage(
        'Password reset sent',
        'Password reset email sent.',
        BottomAlertType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Reset failed', e.toString(), BottomAlertType.error);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 30),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            "Sign In",
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
                            "Please fill in your information to continue.",
                            style: TextStyle(
                              color: MyColors.secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30.0,
                            vertical: 20,
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
                              hint: Text(
                                "johndoe@example.com",
                                style: TextStyle(
                                  color: MyColors.secondaryText,
                                  fontSize: 16,
                                ),
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
                              prefixIcon: Icon(
                                Icons.lock,
                                color: MyColors.primary,
                              ),
                              hint: Text(
                                "*********",
                                style: TextStyle(
                                  color: MyColors.secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Don't have an account yet?",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: MyColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    onTap: () {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (builder) => SignUp(),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                    child: Text(
                                      "Register",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: MyColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: _sendPasswordReset,
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: MyColors.goldAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            signIn();
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
                                "Sign in",
                                style: TextStyle(
                                  color: MyColors.buttonPrimaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Or continue with",
                          style: TextStyle(
                            color: MyColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 20),
                        InkWell(
                          onTap: () async {
                            setState(() {
                              isLoading = true;
                            });
                            try {
                              await signInWithGoogle();
                            } catch (e) {
                              if (!context.mounted) return;
                              setState(() {
                                isLoading = false;
                              });
                              _showMessage(
                                'Google sign in failed',
                                e.toString(),
                                BottomAlertType.error,
                              );
                            }
                          },
                          child: Container(
                            width: MediaQuery.widthOf(context),
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                "Continue with Google",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            try {
                              await signInWithPhone();
                            } catch (e) {
                              if (!context.mounted) return;
                              setState(() {
                                isLoading = false;
                              });
                              _showMessage(
                                'Phone sign in failed',
                                e.toString(),
                                BottomAlertType.error,
                              );
                            }
                          },
                          child: Container(
                            width: MediaQuery.widthOf(context),
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 30),
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
                                    "Continue with Phone",
                                    style: TextStyle(
                                      color: MyColors.primaryText,
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

                        SizedBox(height: 50),
                      ],
                    ),
                  ),
                );
              },
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
    super.dispose();
  }
}
