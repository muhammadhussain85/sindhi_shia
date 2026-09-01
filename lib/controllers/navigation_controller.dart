import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavigationController extends GetxController {
  final currentIndex = 0.obs;

  final List<GlobalKey<NavigatorState>> navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Switches to [index], or pops to root if already on that tab.
  void goToTab(int index) {
    if (currentIndex.value == index) {
      navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      currentIndex.value = index;
    }
  }
}
