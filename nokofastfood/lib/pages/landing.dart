import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/pages/home_page.dart';
import 'package:nokofastfood/pages/legal_page.dart';

import '../constants/colors.dart';
import 'auth/sign_up.dart';

class Landing extends StatefulWidget {
  const Landing({super.key});

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final isLandscape = size.width > size.height;
          final horizontalPadding = size.width < 420 ? 24.0 : 36.0;
          final buttonWidth = size.width < 620 ? double.infinity : 520.0;
          final heroGap = (constraints.maxHeight * (isLandscape ? 0.18 : 0.48))
              .clamp(90.0, 520.0)
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                isLandscape
                    ? 'assets/images/land_double_berger.jpeg'
                    : 'assets/images/port_double_berger.jpeg',
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight -
                          MediaQuery.paddingOf(context).vertical -
                          52,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Noko Fast Food',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: MyColors.primaryText,
                            fontSize: size.width < 360 ? 28 : 34,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            'Fresh meals, quick checkout, and simple ordering.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MyColors.primaryText.withValues(
                                alpha: 0.86,
                              ),
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: heroGap),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: buttonWidth),
                          child: Column(
                            children: [
                              _LandingButton(
                                label: 'Order Your First Meal',
                                filled: true,
                                onTap: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (builder) => const SignUp(),
                                    ),
                                    ((route) => false),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              _LandingButton(
                                label: 'Continue as Guest',
                                onTap: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (builder) => const HomePage(),
                                    ),
                                    ((route) => false),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _LegalLink(
                              label: 'Terms & Conditions',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LegalPage.terms(),
                                ),
                              ),
                            ),
                            const Text(
                              'and',
                              style: TextStyle(
                                color: MyColors.primaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _LegalLink(
                              label: 'Privacy Policy',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LegalPage.privacy(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandingButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _LandingButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? MyColors.buttonPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: MyColors.buttonPrimary, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MyColors.buttonPrimaryText,
                fontSize: MediaQuery.sizeOf(context).width < 340 ? 14 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: MyColors.secondaryText,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: MyColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
