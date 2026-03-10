import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import 'member_avatar.dart';

class MemberListTile extends StatelessWidget {
  const MemberListTile({
    super.key,
    required this.member,
    required this.onTap,
    this.isCheckedIn = false,
    this.isSelected = false,
    this.inMultiSelectMode = false,
    this.onLongPress,
  });

  final Member member;
  final VoidCallback onTap;
  final bool isCheckedIn;
  final bool isSelected;
  final bool inMultiSelectMode;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? AppColors.actionPrimary.withAlpha(10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Selection indicator overlay on avatar
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                  MemberAvatar(member: member, size: 52),
                  if (isSelected)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.actionPrimary.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    member.plan != null
                        ? '${member.plan}  ·  ID: ${member.id}'
                        : 'ID: ${member.id}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (inMultiSelectMode) {
      return Icon(
        isSelected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? AppColors.actionPrimary : AppColors.textTertiary,
        size: 24,
      );
    }
    if (isCheckedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Confirmed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      );
    }
    return const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textTertiary,
      size: 24,
    );
  }
}
