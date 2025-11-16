import 'package:flutter/material.dart';

// Centralized app theme and color helpers (Material Blue primary scheme)
const MaterialColor kPrimarySwatch = Colors.blue;

final Color kPrimaryColor = Colors.blue.shade700;
final Color kPrimaryLight = Colors.blue.shade200;
final Color kPrimaryDark = Colors.blue.shade900;

final ThemeData appTheme = ThemeData(
  primarySwatch: kPrimarySwatch,
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: kPrimarySwatch,
  ).copyWith(secondary: Colors.blueAccent, primary: kPrimaryColor),
  useMaterial3: true,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor, // Material Blue background
      foregroundColor: Colors.white, // White text on buttons
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
  ),
);
