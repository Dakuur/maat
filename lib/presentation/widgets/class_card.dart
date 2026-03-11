import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/fitness_class.dart';

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.fitnessClass,
    required this.onTap,
    this.isJoined = false,
  });

  final FitnessClass fitnessClass;
  final VoidCallback onTap;
  /// True when the signed-in user is personally enrolled in this class.
  final bool isJoined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');
    final fc = fitnessClass;

    // Border priority: joined (green) > full (red) > default
    final borderColor = isJoined
        ? AppColors.success
        : fc.isFull
            ? AppColors.error
            : AppColors.border;
    final borderWidth = (isJoined || fc.isFull) ? 1.5 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isJoined
              ? AppColors.success.withAlpha(8)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags row + optional "You're in" badge on the right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: fc.tags
                        .take(3)
                        .map((tag) => _TagChip(
                              label: tag,
                              color: AppColors.colorForTag(tag),
                            ))
                        .toList(),
                  ),
                ),
                if (isJoined) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.success.withAlpha(80)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          "You're in",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Class name
            Text(
              fc.name,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Time range
            Text(
              '${timeFmt.format(fc.startTime)} – ${timeFmt.format(fc.endTime)}',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 16,
                    color: isJoined
                        ? AppColors.success.withAlpha(180)
                        : AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${fc.attendeeCount}/${fc.maxCapacity} attendees',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fc.isFull ? AppColors.error : null,
                    fontWeight: fc.isFull ? FontWeight.w600 : null,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(fc.instructor, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
