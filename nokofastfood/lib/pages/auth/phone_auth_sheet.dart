import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';

Future<UserCredential?> showPhoneAuthSheet(BuildContext context) {
  return showModalBottomSheet<UserCredential?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PhoneAuthSheet(),
  );
}

class _PhoneAuthSheet extends StatefulWidget {
  const _PhoneAuthSheet();

  @override
  State<_PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends State<_PhoneAuthSheet> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  String? _error;
  String? _message;
  bool _isSending = false;
  bool _isVerifying = false;

  bool get _codeSent => _verificationId != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    final phone = _normalisePhone(_phoneController.text);
    if (phone == null) {
      setState(() {
        _error = 'Enter a valid phone number with a country code.';
        _message = null;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
      _message = 'Sending code to $phone...';
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (credential) async {
        await _signInWithCredential(credential);
      },
      verificationFailed: (exception) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _message = null;
          _error = _friendlyPhoneError(exception);
        });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isSending = false;
          _message = 'Enter the 6-digit code sent to $phone.';
          _error = null;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSending = false;
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (verificationId == null) {
      setState(() {
        _error = 'Request a verification code first.';
      });
      return;
    }
    if (code.length < 6) {
      setState(() {
        _error = 'Enter the 6-digit verification code.';
      });
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
      _error = null;
      _message = 'Verifying your phone number...';
    });

    try {
      final userCredential = await _auth.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pop(context, userCredential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _message = null;
        _error = _friendlyPhoneError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _message = null;
        _error = 'Phone verification failed. Please try again.';
      });
    }
  }

  String? _normalisePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (compact.isEmpty) return null;

    final phone = compact.startsWith('+')
        ? compact
        : compact.startsWith('0')
        ? '+27${compact.substring(1)}'
        : compact.startsWith('27')
        ? '+$compact'
        : '+$compact';

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return null;
    }
    return phone;
  }

  String _friendlyPhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Enter a valid phone number, including the country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'That verification code is not correct. Please check it and try again.';
      case 'quota-exceeded':
        return 'SMS quota has been reached for now. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled in Firebase yet.';
      default:
        return e.message ?? 'Phone verification failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: MyColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MyColors.primary.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MyColors.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MyColors.primary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          color: MyColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone verification',
                              style: TextStyle(
                                color: MyColors.primaryText,
                                fontSize: 18,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use SMS to sign in or create an account.',
                              style: TextStyle(
                                color: MyColors.secondaryText,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phoneController,
                    enabled: !_codeSent && !_isSending && !_isVerifying,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: MyColors.primaryText),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: MyColors.primary,
                      ),
                      hintText: '+27 82 123 4567',
                      hintStyle: const TextStyle(color: MyColors.secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: MyColors.primaryText),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.password,
                          color: MyColors.primary,
                        ),
                        hintText: 'Verification code',
                        hintStyle: const TextStyle(
                          color: MyColors.secondaryText,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: MyColors.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: MyColors.error,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MyColors.buttonPrimary,
                      ),
                      onPressed: _isSending || _isVerifying
                          ? null
                          : _codeSent
                          ? _verifyCode
                          : _sendCode,
                      child: Text(_codeSent ? 'Verify code' : 'Send code'),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isSending || _isVerifying
                            ? null
                            : () => _sendCode(resend: true),
                        child: const Text('Resend code'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
