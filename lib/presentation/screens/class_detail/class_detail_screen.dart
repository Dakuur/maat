import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/checkin_provider.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/attendee_list_tile.dart';
import '../../../presentation/widgets/kiosk_button.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.fitnessClass});

  final FitnessClass fitnessClass;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('HH:mm');
    final fc = widget.fitnessClass;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(fc.name),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),

          // ── Class info ───────────────────────────────────────────────────
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
                    text: '${fc.attendeeCount} / ${fc.maxCapacity} attendees',
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

          // ── Attendees header ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              24,
              AppConstants.pagePadding,
              4,
            ),
            sliver: SliverToBoxAdapter(
              child: Text('Attendees', style: theme.textTheme.headlineMedium),
            ),
          ),

          // ── Attendees list ───────────────────────────────────────────────
          const _AttendeesList(),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      // ── Bottom CTA ────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: KioskButton(
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _AttendeesList extends StatelessWidget {
  const _AttendeesList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    if (provider.isLoadingCheckIns) {
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
          padding:
              const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
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
      itemBuilder: (_, i) => AttendeeListTile(checkIn: checkIns[i]),
    );
  }
}
