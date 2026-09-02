import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  static Color? fromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    final color = int.tryParse(buffer.toString(), radix: 16);
    if (color == null) return null;
    return Color(color);
  }

  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${a.toInt().toRadixString(16).padLeft(2, '0')}'
      '${r.toInt().toRadixString(16).padLeft(2, '0')}'
      '${g.toInt().toRadixString(16).padLeft(2, '0')}'
      '${b.toInt().toRadixString(16).padLeft(2, '0')}';
}
