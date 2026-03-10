import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../data/models/member.dart';
import '../../../presentation/providers/checkin_provider.dart';
import '../../../presentation/widgets/kiosk_button.dart';
import '../../../presentation/widgets/member_avatar.dart';

class CheckInConfirmScreen extends StatefulWidget {
  const CheckInConfirmScreen({
    super.key,
    required this.member,
    required this.fitnessClass,
  });

  final Member member;
  final FitnessClass fitnessClass;

  @override
  State<CheckInConfirmScreen> createState() => _CheckInConfirmScreenState();
}

class _CheckInConfirmScreenState extends State<CheckInConfirmScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for success state to trigger navigation as a side-effect,
    // not inside build.
    context.read<CheckInProvider>().addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = context.read<CheckInProvider>().state;
    if (state == CheckInState.success) {
      Navigator.of(context).pushReplacementNamed(
        AppRouter.success,
        arguments: {
          'member': widget.member,
          'fitnessClass': widget.fitnessClass,
        },
      );
    }
  }

  @override
  void dispose() {
    context.read<CheckInProvider>().removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CheckInProvider>();
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEEE, d MMMM yyyy');
    final fc = widget.fitnessClass;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Confirm Check-In'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Member card ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    MemberAvatar(member: widget.member, size: 96),
                    const SizedBox(height: 20),
                    Text(
                      widget.member.fullName,
                      style: theme.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Member ID: ${widget.member.id}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (widget.member.plan != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.actionPrimary.withAlpha(10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.actionPrimary.withAlpha(40)),
                        ),
                        child: Text(
                          widget.member.plan!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Class / date info ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.fitness_center_rounded,
                      label: 'Class',
                      value: fc.name,
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value:
                          '${timeFmt.format(fc.startTime)} – ${timeFmt.format(fc.endTime)}',
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateFmt.format(DateTime.now()),
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'Instructor',
                      value: fc.instructor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Inline error banners ────────────────────────────────────
              if (provider.state == CheckInState.alreadyCheckedIn) ...[
                _Banner(
                  color: AppColors.warning,
                  icon: Icons.warning_amber_rounded,
                  message:
                      '${widget.member.firstName} is already checked in to this class.',
                ),
                const SizedBox(height: 16),
              ],
              if (provider.state == CheckInState.error) ...[
                _Banner(
                  color: AppColors.error,
                  icon: Icons.error_outline_rounded,
                  message: provider.errorMessage ?? 'An error occurred.',
                ),
                const SizedBox(height: 16),
              ],

              // ── CTA ─────────────────────────────────────────────────────
              KioskButton(
                label: 'Check In',
                icon: Icons.check_rounded,
                isLoading: provider.state == CheckInState.loading,
                onPressed: provider.state == CheckInState.loading
                    ? null
                    : () =>
                        context.read<CheckInProvider>().submitCheckIn(),
              ),
              const SizedBox(height: 12),
              KioskButton(
                label: 'Cancel',
                variant: KioskButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.divider),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
