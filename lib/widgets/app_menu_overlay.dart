import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class MenuOverlayItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const MenuOverlayItem({required this.icon, required this.label, this.onTap});
}

class AppMenuOverlay extends StatelessWidget {
  final Widget child;
  final bool isOpen;
  final VoidCallback onClose;
  final List<MenuOverlayItem> items;

  const AppMenuOverlay({
    super.key,
    required this.child,
    required this.isOpen,
    required this.onClose,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withOpacity(0.05)),
              ),
            ),
          ),
          Positioned(
            top: 118,
            left: 16,
            right: 16,
            child: Column(
              children:
                  items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _MenuButton(item: item),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final MenuOverlayItem item;

  const _MenuButton({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.brandSecondary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 32, color: AppColors.brandPrimary),
              const SizedBox(width: 16),
              Text(
                item.label,
                style: AppTypography.heading2.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
