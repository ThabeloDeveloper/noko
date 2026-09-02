import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:shimmer/shimmer.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: MediaQuery.widthOf(context),
        height: MediaQuery.heightOf(context),
        color: Colors.black.withAlpha(100),
        child: Center(
          child: Shimmer.fromColors(
            baseColor: MyColors.surfaceCard,
            highlightColor: MyColors.primary,
            child: Text(
              "NOKO",
              style: GoogleFonts.dancingScript(
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
