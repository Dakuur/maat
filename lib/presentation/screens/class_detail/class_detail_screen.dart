import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/check_in.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/checkin_provider.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/attendee_list_tile.dart';
import '../../../presentation/widgets/fade_slide_in.dart';
import '../../../presentation/widgets/kiosk_button.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.fitnessClass});

  final FitnessClass fitnessClass;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  // ── Multi-select state ─────────────────────────────────────────────────────
  bool _multiSelectMode = false;
  final Set<String> _selectedCheckInIds = {};

  // ── Optimistic-remove animation state ─────────────────────────────────────
  // IDs currently fading out before being removed from the provider list.
  final Set<String> _animatingOutIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ClassProvider>()
          .watchCheckInsForClass(widget.fitnessClass.id);
      context.read<CheckInProvider>().selectClass(widget.fitnessClass);
    });
  }

  @override
  void dispose() {
    context.read<ClassProvider>().stopWatchingCheckIns();
    super.dispose();
  }

  // ── Multi-select helpers ───────────────────────────────────────────────────

  void _enterMultiSelect(String checkInId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _multiSelectMode = true;
      _selectedCheckInIds.add(checkInId);
    });
  }

  void _toggleAttendee(String checkInId) {
    setState(() {
      if (_selectedCheckInIds.contains(checkInId)) {
        _selectedCheckInIds.remove(checkInId);
        if (_selectedCheckInIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedCheckInIds.add(checkInId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedCheckInIds.clear();
    });
  }

  // ── Remove helpers ─────────────────────────────────────────────────────────

  /// Bulk remove with optimistic UI:
  /// 1. Confirm with dialog.
  /// 2. Immediately fade selected items out (AnimatedOpacity → 0).
  /// 3. After the animation, call [ClassProvider.optimisticRemoveIds] which
  ///    removes them from the local list and fires background Firestore deletes.
  Future<void> _removeSelected() async {
    final count = _selectedCheckInIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete attendees?'),
        content: Text(
          '¿Delete $count student${count == 1 ? '' : 's'} from the class?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ids = _selectedCheckInIds.toList();

    // Exit multi-select and start the fade-out animation.
    setState(() {
      _multiSelectMode = false;
      _selectedCheckInIds.clear();
      _animatingOutIds.addAll(ids);
    });

    // Capture provider before the async gap to satisfy the lint rule.
    final classProvider = context.read<ClassProvider>();

    // Wait for the opacity animation to complete.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Optimistic remove: list updates instantly, Firestore writes run in bg.
    classProvider.optimisticRemoveIds(ids);
    setState(() => _animatingOutIds.clear());
  }

  void _handleAttendeeTap(BuildContext ctx, CheckIn checkIn) {
    if (_multiSelectMode) {
      _toggleAttendee(checkIn.id);
    } else {
      _showAttendeeSheet(ctx, checkIn);
    }
  }

  void _showAttendeeSheet(BuildContext context, CheckIn checkIn) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttendeeSheet(
        checkIn: checkIn,
        onRemove: () {
          Navigator.of(context).pop();
          // Fade the item out, then optimistically remove it.
          // Capture provider here (sync) to avoid using context across gaps.
          final classProvider = context.read<ClassProvider>();
          setState(() => _animatingOutIds.add(checkIn.id));
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            classProvider.optimisticRemoveIds([checkIn.id]);
            setState(() => _animatingOutIds.remove(checkIn.id));
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');
    final fc = widget.fitnessClass;

    // Live attendee count from the active stream.
    final classProvider = context.watch<ClassProvider>();
    final liveCount = classProvider.isLoadingCheckIns
        ? fc.attendeeCount
        : classProvider.currentCheckIns.length;
    final isFull = liveCount >= fc.maxCapacity;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          // Keep existing list visible while reconnecting (no blank flash).
          context
              .read<ClassProvider>()
              .watchCheckInsForClass(widget.fitnessClass.id, keepExisting: true);
          // Give the stream a moment to emit before hiding the spinner.
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          // Required for RefreshIndicator to trigger on short lists.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: AppColors.surface,
              leading: _multiSelectMode
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _exitMultiSelect,
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
              title: _multiSelectMode
                  ? Text('${_selectedCheckInIds.length} selected')
                  : Text(fc.name),
              // Refresh button removed: use pull-to-refresh instead.
              actions: const [],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.border),
              ),
            ),

            // ── Class info ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fc.name, style: theme.textTheme.displayMedium),
                    const SizedBox(height: 20),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      text:
                          '${timeFmt.format(fc.startTime)} – ${timeFmt.format(fc.endTime)}',
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.person_rounded, text: fc.instructor),
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.people_rounded,
                      text: '$liveCount / ${fc.maxCapacity} attendees',
                      color: isFull ? AppColors.error : null,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: fc.tags.map((tag) {
                        final color = AppColors.colorForTag(tag);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withAlpha(77)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Attendees header ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                24,
                AppConstants.pagePadding,
                4,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('Attendees', style: theme.textTheme.headlineMedium),
                    if (!_multiSelectMode) ...[
                      const Spacer(),
                      Text(
                        'Hold to select',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Attendees list ─────────────────────────────────────────────
            _AttendeesList(
              multiSelectMode: _multiSelectMode,
              selectedIds: _selectedCheckInIds,
              animatingOutIds: _animatingOutIds,
              onLongPress: (c) => _enterMultiSelect(c.id),
              onTap: _handleAttendeeTap,
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),

      // ── Bottom CTA ──────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: _multiSelectMode
              ? KioskButton(
                  label: _selectedCheckInIds.isEmpty
                      ? 'Select attendees'
                      : 'Delete ${_selectedCheckInIds.length} '
                          'student${_selectedCheckInIds.length == 1 ? '' : 's'}',
                  variant: KioskButtonVariant.danger,
                  icon: Icons.person_remove_rounded,
                  onPressed:
                      _selectedCheckInIds.isEmpty ? null : _removeSelected,
                )
              : KioskButton(
                  label: 'Add Check-In',
                  icon: Icons.add_rounded,
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRouter.memberSearch,
                    arguments: widget.fitnessClass,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: color != null ? FontWeight.w600 : null,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Attendees list sliver ─────────────────────────────────────────────────────

class _AttendeesList extends StatelessWidget {
  const _AttendeesList({
    required this.multiSelectMode,
    required this.selectedIds,
    required this.animatingOutIds,
    required this.onLongPress,
    required this.onTap,
  });

  final bool multiSelectMode;
  final Set<String> selectedIds;

  /// IDs currently in their fade-out animation (opacity 1 → 0).
  final Set<String> animatingOutIds;

  final void Function(CheckIn) onLongPress;
  final void Function(BuildContext, CheckIn) onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    // Show spinner only on the very first load (no data yet).
    if (provider.isLoadingCheckIns && provider.currentCheckIns.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final checkIns = provider.currentCheckIns;
    if (checkIns.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 52, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No attendees yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "Add Check-In" to register the first member.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: checkIns.length,
      itemBuilder: (ctx, i) {
        final checkIn = checkIns[i];
        final isAnimatingOut = animatingOutIds.contains(checkIn.id);

        // AnimatedOpacity wraps every row so we can smoothly fade it out
        // before removing it from the list (optimistic-UI exit animation).
        // ValueKey ensures Flutter matches the widget by ID across rebuilds,
        // enabling the implicit animation to trigger correctly.
        return AnimatedOpacity(
          key: ValueKey(checkIn.id),
          opacity: isAnimatingOut ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          child: FadeSlideIn(
            key: ValueKey('slide_${checkIn.id}'),
            index: i,
            child: AttendeeListTile(
              checkIn: checkIn,
              isSelected: selectedIds.contains(checkIn.id),
              inMultiSelectMode: multiSelectMode,
              onLongPress:
                  multiSelectMode ? null : () => onLongPress(checkIn),
              onTap: () => onTap(ctx, checkIn),
            ),
          ),
        );
      },
    );
  }
}

// ── Attendee detail sheet ─────────────────────────────────────────────────────

class _AttendeeSheet extends StatelessWidget {
  const _AttendeeSheet({required this.checkIn, required this.onRemove});

  final CheckIn checkIn;
  final VoidCallback onRemove;

  static const double _avatarSize = 72;
  static const _palette = [
    Color(0xFFE87D3E),
    Color(0xFF30A046),
    Color(0xFF0066CC),
    Color(0xFFD70015),
    Color(0xFF4B44C8),
  ];

  Color get _avatarColor =>
      _palette[checkIn.memberId.hashCode.abs() % _palette.length];

  String get _initials {
    final parts = checkIn.memberName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return checkIn.memberName.isNotEmpty
        ? checkIn.memberName[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(_avatarSize / 2),
            child: checkIn.memberProfilePicture != null
                ? CachedNetworkImage(
                    imageUrl: checkIn.memberProfilePicture!,
                    width: _avatarSize,
                    height: _avatarSize,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackAvatar(),
                  )
                : _fallbackAvatar(),
          ),
          const SizedBox(height: 16),
          Text(checkIn.memberName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Checked in at ${timeFmt.format(checkIn.checkedInAt)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: (checkIn.status == CheckInStatus.confirmed
                      ? AppColors.success
                      : AppColors.warning)
                  .withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              checkIn.status.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: checkIn.status == CheckInStatus.confirmed
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _confirmRemove(context),
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: AppColors.error),
              label: const Text(
                'Remove from class',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() => Container(
        width: _avatarSize,
        height: _avatarSize,
        color: _avatarColor,
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _avatarSize * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  void _confirmRemove(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove attendee?'),
        content: Text(
          '${checkIn.memberName} will be removed from this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onRemove();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
