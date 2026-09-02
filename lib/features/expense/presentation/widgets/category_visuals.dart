import 'package:flutter/material.dart';

/// Maps stored category icon names → Material [IconData], and hex strings →
/// [Color]. Runtime string→IconData lookup requires an explicit map (Flutter
/// tree-shakes icons), so we keep a curated set here.
class CategoryVisuals {
  CategoryVisuals._();

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'local_hospital': Icons.local_hospital,
    'receipt_long': Icons.receipt_long,
    'school': Icons.school,
    'movie': Icons.movie,
    'flight': Icons.flight,
    'trending_up': Icons.trending_up,
    'payments': Icons.payments,
    'category': Icons.category,
    'home': Icons.home,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'coffee': Icons.coffee,
    'card_giftcard': Icons.card_giftcard,
    'phone_android': Icons.phone_android,
    'wifi': Icons.wifi,
    'water_drop': Icons.water_drop,
    'bolt': Icons.bolt,
    'savings': Icons.savings,
    'work': Icons.work,
    'local_gas_station': Icons.local_gas_station,
    'more_horiz': Icons.more_horiz,
  };

  /// The set of icons users can pick from when creating a category.
  static List<String> get pickable => _icons.keys.toList();

  static IconData icon(String name) => _icons[name] ?? Icons.category;

  static Color color(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? const Color(0xFF95A5A6) : Color(parsed);
  }

  /// A curated palette users can pick a category color from.
  static const List<String> palette = [
    '#FF5722', '#3498DB', '#E74C3C', '#27AE60', '#1ABC9C',
    '#E67E22', '#9B59B6', '#00BCD4', '#2ECC71', '#F39C12',
    '#E91E63', '#34495E',
  ];
}
