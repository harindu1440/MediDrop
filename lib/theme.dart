import 'package:flutter/material.dart';

// Centralized app theme and color helpers
const MaterialColor kPrimarySwatch = Colors.green;

final Color kPrimaryColor = Colors.green.shade700;
final Color kPrimaryLight = Colors.green.shade200;
final Color kPrimaryDark = Colors.green.shade900;

final ThemeData appTheme = ThemeData(
  primarySwatch: kPrimarySwatch,
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: kPrimarySwatch,
  ).copyWith(secondary: Colors.greenAccent, primary: kPrimaryColor),
  useMaterial3: true,
);
