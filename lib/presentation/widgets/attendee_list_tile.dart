import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/check_in.dart';

class AttendeeListTile extends StatelessWidget {
  const AttendeeListTile({super.key, required this.checkIn});

  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _Avatar(checkIn: checkIn),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(checkIn.memberName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Checked in at ${timeFmt.format(checkIn.checkedInAt)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _StatusBadge(status: checkIn.status),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.checkIn});

  final CheckIn checkIn;

  static const double _size = 44;
  static const _palette = [
    Color(0xFFE87D3E),
    Color(0xFF30A046),
    Color(0xFF0066CC),
    Color(0xFFD70015),
    Color(0xFF4B44C8),
  ];

  String get _initials {
    final parts = checkIn.memberName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return checkIn.memberName.isNotEmpty
        ? checkIn.memberName[0].toUpperCase()
        : '?';
  }

  Color get _color =>
      _palette[checkIn.memberId.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_size / 2),
      child: checkIn.memberProfilePicture != null
          ? CachedNetworkImage(
              imageUrl: checkIn.memberProfilePicture!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: _size,
        height: _size,
        color: _color,
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CheckInStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      CheckInStatus.confirmed => (
          AppColors.success,
          AppColors.success.withAlpha(30)
        ),
      CheckInStatus.registered => (
          AppColors.warning,
          AppColors.warning.withAlpha(30)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
