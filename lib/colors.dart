import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyColors {
  static const primaryColor = Color.fromARGB(255, 29, 29, 29);
  static const secondaryColor = Color.fromARGB(255, 48, 51, 54);
  static const trecondaryColor = Color.fromARGB(255, 93, 97, 100);
  static const forthyColor = Color.fromARGB(255, 126, 130, 135);
  static const fivyColor = Color.fromARGB(255, 195, 197, 201);
  static const remove = Color.fromARGB(255, 228, 55, 55);
  static const orangeDivider = Color(0xffffc77e);
  static const contactDivider = Color(0xff89cdbb);
  static const drawalDivider = Color(0xff0b4e3d);
  static const drawalBackground = Color(0xff141414);
}

const Color defaultTagColor = Color(0xFF808080);

/// Safely parses a tag color string that may be stored in various formats:
/// - "0xFF808080" (full hex with prefix)
/// - "A0A0A0" or "FFA0A0A0" (hex without prefix)
/// - "4294967295" (decimal integer from Color.value)
/// - null or empty (returns [defaultTagColor])
Color parseTagColor(String? colorStr) {
  if (colorStr == null || colorStr.isEmpty) return defaultTagColor;
  if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
    return Color(int.parse(colorStr));
  }
  final asInt = int.tryParse(colorStr);
  if (asInt != null) return Color(asInt);
  final asHex = int.tryParse(colorStr, radix: 16);
  if (asHex != null) {
    return Color(colorStr.length <= 6 ? (0xFF000000 | asHex) : asHex);
  }
  return defaultTagColor;
}

const Color bgColor = Color(0xFF212227);
const Color cardColor = Color(0xFF2D2E33);
const Color cardColor2 = Color.fromARGB(255, 55, 56, 61);
const Color cardColor3 = Color.fromARGB(255, 71, 72, 77);
const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);
