import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum KioskButtonVariant { primary, secondary, danger }

/// Large, accessible button sized for kiosk touch interaction.
class KioskButton extends StatelessWidget {
  const KioskButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = KioskButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final KioskButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild();

    return SizedBox(
      height: 64,
      width: double.infinity,
      child: switch (variant) {
        KioskButtonVariant.primary => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        KioskButtonVariant.secondary => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        KioskButtonVariant.danger => ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: child,
          ),
      },
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Text(label),
        ],
      );
    }
    return Text(label);
  }
}
