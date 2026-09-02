import 'package:nokofastfood/constants/api.dart';

class JsonData {
  static final categories = [
    "On Special",
    "Burger",
    "Pizza",
    "Chicken",
    "Beef & Meat",
    "Game Meat",
    "Biltong",
    "Salads & Sides",
    "Drinks",
    "Cakes & Desserts",
  ];

  static final pagerImages = [
    '${Api.baseURL}images/land_pizza.jpeg',
    '${Api.baseURL}images/land_double_berger.jpeg',
    '${Api.baseURL}images/land_berger_chips.jpeg',
  ];
  static final productImages = [
    "${Api.baseURL}images/port_double_berger.jpeg",
    "${Api.baseURL}images/port_berger_chips.jpeg",
    "${Api.baseURL}images/port_pizza.jpeg",
  ];
}
