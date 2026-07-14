import 'package:flutter/material.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; 
  final bool centerTitle; 
  final Color? backgroundColor; 
  final Color? dividerColor;
  final Widget? rightAction; // e.g., profile icon button
  final Widget? leading; // leftmost widget (e.g., profile/menu)

  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.backgroundColor,
    this.dividerColor,
    this.rightAction,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      
      // App Bar's title
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      actions: rightAction != null ? [rightAction!] : null,
      
      // divider line
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0), //height of the divider line
        child: Container(
          color: dividerColor ?? Colors.grey.shade300,
          height: 1.0, //thickness of the line
        ),
      ),
    );
  }

  // Required for PreferredSizeWidget
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
