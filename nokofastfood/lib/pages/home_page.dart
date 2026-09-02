import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/pages/auth/sign_in.dart';
import 'package:nokofastfood/pages/navigation/account.dart';
import 'package:nokofastfood/pages/navigation/home.dart';
import 'package:nokofastfood/pages/navigation/inbox.dart';
import 'package:nokofastfood/pages/navigation/orders.dart';

import '../constants/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Widget> pagesList = [Home(), Orders(), Inbox(), Account()];
  int index = 0;

  void _onTabTapped(int i) {
    if ((i == 1 || i == 2 || i == 3) &&
        FirebaseAuth.instance.currentUser == null) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => const SignIn()),
      );
    } else {
      setState(() {
        index = i;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth >= 700;
        return Scaffold(
          backgroundColor: MyColors.background,
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: _onTabTapped,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.black,
                  selectedIconTheme: const IconThemeData(
                    color: MyColors.primary,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: MyColors.surfaceCard,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: MyColors.primary,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: MyColors.surfaceCard,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.reorder),
                      label: Text('Order'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bubble_chart),
                      label: Text('Inbox'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text('Account'),
                    ),
                  ],
                ),
              Expanded(child: pagesList[index]),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : BottomNavigationBar(
                  currentIndex: index,
                  onTap: _onTabTapped,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.black,
                  selectedItemColor: MyColors.primary,
                  unselectedItemColor: MyColors.surfaceCard,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.reorder),
                      label: 'Order',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bubble_chart),
                      label: 'Inbox',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person),
                      label: 'Account',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
