import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/colors.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final List<String> sections;

  const LegalPage({super.key, required this.title, required this.sections});

  factory LegalPage.terms() {
    return const LegalPage(
      title: 'Terms & Conditions',
      sections: [
        'Orders are accepted by the selected restaurant and may be declined if items become unavailable.',
        'Delivery times are estimates and can change because of restaurant preparation, driver availability, traffic, or weather.',
        'Customers must provide a reachable phone number and accurate delivery address.',
        'Paid order cancellations may require the restaurant to manually send back the money.',
        'Misuse of reviews, chat, promotions, or payment flows may lead to account restriction.',
      ],
    );
  }

  factory LegalPage.privacy() {
    return const LegalPage(
      title: 'Privacy Policy',
      sections: [
        'Noko stores customer profile details, saved addresses, orders, chat messages, device notification tokens, and review activity in Firebase.',
        'Location and address data is used to estimate delivery, show map tracking, and help restaurants and drivers fulfil orders.',
        'Payment card details are handled by Peach Payments and are not stored in the customer app.',
        'Customers can request profile updates and remove saved addresses from the Account screen.',
        'Operational data may be shared with restaurants, drivers, and administrators only where needed to fulfil orders or support customers.',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: MyColors.background,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MyColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MyColors.divider),
            ),
            child: Text(
              sections[index],
              style: const TextStyle(
                color: MyColors.secondaryText,
                height: 1.45,
              ),
            ),
          );
        },
      ),
    );
  }
}
