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
  });

  final Member member;
  final VoidCallback onTap;
  final bool isCheckedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 52),
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
            if (isCheckedIn)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Confirmed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 24),
          ],
        ),
      ),
    );
  }
}
