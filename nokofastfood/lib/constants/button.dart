import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../pages/auth/sign_up.dart';
import 'colors.dart';

class MyButton extends StatelessWidget {
  const MyButton({super.key, this.buttonText, this.buttonFunction});
  final String? buttonText;
  final VoidCallback? buttonFunction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          buttonFunction ??
          () {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (builder) => const SignUp()),
              ((route) => false),
            );
          },
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        height: 50,
        decoration: BoxDecoration(
          color: MyColors.buttonPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            buttonText ?? "",
            style: TextStyle(
              color: MyColors.buttonPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
