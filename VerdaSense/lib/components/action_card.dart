import 'package:flutter/material.dart';

// A tappable card with an icon, title, and optional caption.
// Used at Home Screen for quick navigation and Upload Image main screen
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? caption;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final background = Theme.of(context).colorScheme.surface;

    return Material(
      color: background,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      
      // Makes the card tappable, showing a ripple animation when pressed
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // ensure the ripple stays within the rounded edges
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          
          // Arrange icon and text vertically
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size:24),
              ),


              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


