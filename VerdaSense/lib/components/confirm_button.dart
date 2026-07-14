import 'package:flutter/material.dart';

/// A reusable confirm button component used across the app
/// for actions like signing in, signing up, and confirming bounding boxes
class ConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;

  const ConfirmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = backgroundColor ?? theme.colorScheme.primary;
    final buttonTextColor = textColor ?? Colors.white;

    return SizedBox(
      width: width ?? double.infinity, // use given width or fallback to full width
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: buttonTextColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : icon != null
                ? Icon(icon, size: 20)
                : const SizedBox.shrink(),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: buttonTextColor,
          ),
        ),
      ),
    );
  }
}
