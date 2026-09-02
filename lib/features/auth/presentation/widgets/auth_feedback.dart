import 'package:flutter/material.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';

/// Extracts a user-friendly message from a thrown error.
String failureMessage(Object? error) {
  if (error is Failure) return error.message;
  return 'Something went wrong. Please try again.';
}

void showAuthSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
