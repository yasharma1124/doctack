import 'package:flutter/material.dart';

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.greenAccent.withOpacity(0.2), Colors.greenAccent);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.redAccent.withOpacity(0.2), Colors.redAccent);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.purpleAccent.withOpacity(0.2), Colors.purpleAccent);
  }

  static void _show(BuildContext context, String message, Color bg, Color textColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.check_circle, color: textColor, size: 20),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}