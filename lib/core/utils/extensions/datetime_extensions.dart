import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  String get displayDate {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(this);
  }

  String get displayTime => DateFormat('h:mm a').format(this);
  String get displayDateTime => '$displayDate at $displayTime';
  String get monthYear => DateFormat('MMMM yyyy').format(this);
  String get isoDate => DateFormat('yyyy-MM-dd').format(this);

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  DateTime get startOfMonth => DateTime(year, month);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);
}
