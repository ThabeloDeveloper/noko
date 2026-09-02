import 'package:flutter/material.dart';

import 'colors.dart';

class OtpFields extends StatelessWidget {
  const OtpFields({super.key, required this.codeController});

  final TextEditingController codeController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: TextField(
        controller: codeController,
        style: TextStyle(color: MyColors.primaryText, fontSize: 16),
        decoration: InputDecoration(
          hint: Text(
            "",
            style: TextStyle(color: MyColors.secondaryText, fontSize: 16),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
