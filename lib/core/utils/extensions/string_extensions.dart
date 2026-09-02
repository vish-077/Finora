extension StringX on String {
  bool get isGmailAddress =>
      isNotEmpty && trim().toLowerCase().endsWith('@gmail.com');

  bool get isValidEmail {
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    return emailRegex.hasMatch(trim());
  }

  String get initials {
    final parts = trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String truncate(int maxLength, {String ellipsis = '…'}) =>
      length <= maxLength ? this : '${substring(0, maxLength - ellipsis.length)}$ellipsis';
}

extension NullableStringX on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => !isNullOrEmpty;
}
