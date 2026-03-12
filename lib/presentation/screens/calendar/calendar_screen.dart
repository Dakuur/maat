import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/calendar_provider.dart';

// Timeline geometry
const double _hourHeight = 80.0;
const int _startHour = 6;
const int _endHour = 23;
const double _labelWidth = 52.0;

// Minimum horizontal velocity (px/s) to register a swipe
const double _swipeThreshold = 300.0;

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // CalendarProvider is app-level (created in app.dart) so sync data
    // persists across navigation. No local provider creation needed.
    return const _CalendarView();
  }
}

// ── Main view (stateful so it owns the day-index counter for animations) ──────

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  int _dayIndex = 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    // Refresh the class list for the current selected day each time the
    // screen is opened. The Google Calendar event cache is preserved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CalendarProvider>().refreshCurrentDay();
    });
  }

  void _goNext() {
    context.read<CalendarProvider>().goToNextDay();
    setState(() {
      _forward = true;
      _dayIndex++;
    });
  }

  void _goPrev() {
    context.read<CalendarProvider>().goToPreviousDay();
    setState(() {
      _forward = false;
      _dayIndex--;
    });
  }

  void _goToday() {
    final cal = context.read<CalendarProvider>();
    final wasAfterToday = cal.selectedDay.isAfter(
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    cal.goToToday();
    setState(() {
      _forward = !wasAfterToday;
      _dayIndex = 0;
    });
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -_swipeThreshold) _goNext();  // swipe left  → next day
    if (v > _swipeThreshold) _goPrev();   // swipe right → prev day
  }

  @override
  Widget build(BuildContext context) {
    final cal = context.watch<CalendarProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Schedule'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: GestureDetector(
        // Detect horizontal swipes anywhere on screen
        onHorizontalDragEnd: _onHorizontalSwipe,
        // Transparent so taps pass through to child widgets
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            _DayNav(
              cal: cal,
              onPrev: _goPrev,
              onNext: _goNext,
              onToday: _goToday,
            ),
            _SyncBar(cal: cal),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  // Incoming page slides in from right (forward) or left (backward).
                  // Outgoing page is faded out beneath it.
                  final isIncoming =
                      (child.key as ValueKey<int>).value == _dayIndex;
                  final begin = isIncoming
                      ? Offset(_forward ? 1.0 : -1.0, 0)
                      : Offset.zero;
                  final end = isIncoming ? Offset.zero : Offset.zero;
                  final slide = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: Curves.easeOutCubic))
                      .animate(animation);
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(
                      opacity: isIncoming
                          ? animation
                          : Tween(begin: 1.0, end: 0.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_dayIndex),
                  child: _Timeline(cal: cal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day navigation bar ────────────────────────────────────────────────────────

class _DayNav extends StatelessWidget {
  const _DayNav({
    required this.cal,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final CalendarProvider cal;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  String _label(DateTime day) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final diff = day.difference(t).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
        vertical: 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Column(
                children: [
                  Text(
                    _label(cal.selectedDay),
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    DateFormat('EEEE, MMMM d').format(cal.selectedDay),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sync bar ──────────────────────────────────────────────────────────────────

class _SyncBar extends StatelessWidget {
  const _SyncBar({required this.cal});
  final CalendarProvider cal;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding, 0, AppConstants.pagePadding, 12),
      child: Row(
        children: [
          // Status / error text — always Expanded so button stays right-aligned
          Expanded(
            child: cal.calendarConnected
                ? Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${cal.cachedEventCount} events synced (±7 days)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.success),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : cal.syncError != null
                    ? Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              cal.syncError!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.error),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: cal.syncing
                ? null
                : () async {
                    if (!auth.isLoggedIn) {
                      await context.read<AuthProvider>().signInWithGoogle();
                    }
                    if (context.mounted) {
                      await context
                          .read<CalendarProvider>()
                          .syncWithGoogleCalendar();
                    }
                  },
            icon: cal.syncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(cal.calendarConnected ? 'Re-sync' : 'Sync with Google'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.cal});
  final CalendarProvider cal;

  /// Earliest hour to display: min of _startHour and the start hour of the
  /// earliest class, so classes before 06:00 are never clipped off the top.
  int _effectiveStart() {
    int start = _startHour;
    for (final fc in cal.classes) {
      if (fc.startTime.hour < start) start = fc.startTime.hour;
    }
    return start;
  }

  @override
  Widget build(BuildContext context) {
    if (cal.loadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }

    final effectiveStart = _effectiveStart();
    final conflicts = cal.conflictClassIds;
    final totalHeight = (_endHour - effectiveStart).toDouble() * _hourHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            ..._buildGrid(effectiveStart),
            ...cal.classes.map(
              (fc) => _ClassBlock(
                fitnessClass: fc,
                hasConflict: conflicts.contains(fc.id),
                isJoined: cal.myJoinedClassIds.contains(fc.id),
                startHour: effectiveStart,
              ),
            ),
            if (_isToday(cal.selectedDay))
              _CurrentTimeLine(startHour: effectiveStart),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  List<Widget> _buildGrid(int startHour) {
    return List.generate(_endHour - startHour, (i) {
      final hour = startHour + i;
      final top = i * _hourHeight;
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        height: _hourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: AppColors.border, width: 1)),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Current time indicator ────────────────────────────────────────────────────

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({required this.startHour});
  final int startHour;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minutesSinceStart =
        (now.hour - startHour) * 60.0 + now.minute.toDouble();
    final top = minutesSinceStart / 60 * _hourHeight;

    if (top < 0 || top > (_endHour - startHour) * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: _labelWidth - 6,
      right: 12,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
          ),
          Expanded(child: Container(height: 2, color: AppColors.error)),
        ],
      ),
    );
  }
}

// ── Class block ───────────────────────────────────────────────────────────────

class _ClassBlock extends StatelessWidget {
  const _ClassBlock({
    required this.fitnessClass,
    required this.hasConflict,
    required this.isJoined,
    required this.startHour,
  });

  final FitnessClass fitnessClass;
  final bool hasConflict;
  final bool isJoined;
  final int startHour;

  double get _top {
    final start = fitnessClass.startTime;
    final minutes = (start.hour - startHour) * 60.0 + start.minute;
    return minutes / 60 * _hourHeight;
  }

  double get _height {
    final duration =
        fitnessClass.endTime.difference(fitnessClass.startTime).inMinutes;
    return (duration / 60 * _hourHeight).clamp(40.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');
    final fc = fitnessClass;
    // Color priority: joined (green) > conflict (red) > default (black)
    // If you're already enrolled, green wins — the conflict is irrelevant.
    final color = isJoined
        ? AppColors.success
        : hasConflict
            ? AppColors.error
            : AppColors.actionPrimary;
    final bgAlpha = isJoined ? 15 : (hasConflict ? 20 : 12);
    final borderAlpha = isJoined ? 160 : (hasConflict ? 160 : 80);
    final borderWidth = (isJoined || hasConflict) ? 1.5 : 1.0;

    return Positioned(
      top: _top,
      left: _labelWidth + 4,
      right: 12,
      height: _height,
      child: GestureDetector(
        onTap: () => Navigator.of(context)
            .pushNamed(AppRouter.classDetail, arguments: fc),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(bgAlpha),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withAlpha(borderAlpha),
              width: borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isJoined) ...[
                          const Icon(Icons.check_circle_rounded,
                              size: 13, color: AppColors.success),
                          const SizedBox(width: 3),
                        ] else if (hasConflict) ...[
                          const Icon(Icons.warning_amber_rounded,
                              size: 13, color: AppColors.error),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            fc.name,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_height > 48)
                      Text(
                        '${timeFmt.format(fc.startTime)} – ${timeFmt.format(fc.endTime)}  ·  ${fc.instructor}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color.withAlpha(180),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fc.isFull ? AppColors.error.withAlpha(20) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fc.attendeeCount}/${fc.maxCapacity}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fc.isFull
                        ? AppColors.error
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
