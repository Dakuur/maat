import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/fitness_class.dart';

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.fitnessClass,
    required this.onTap,
  });

  final FitnessClass fitnessClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');
    final fc = fitnessClass;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags
            Wrap(
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
            const SizedBox(height: 12),

            // Name
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
                const Icon(Icons.people_outline_rounded,
                    size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${fc.attendeeCount} attendees',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  fc.instructor,
                  style: theme.textTheme.bodyMedium,
                ),
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
        color: color.withAlpha(26), // ~10% opacity
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)), // ~30% opacity
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
