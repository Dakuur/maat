import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/class_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().watchTodaysClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroBanner(dateLabel: dateLabel)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.sectionSpacing,
              AppConstants.pagePadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                "Today's classes",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(top: 20, bottom: 40),
            sliver: _ClassList(),
          ),
        ],
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151515), Color(0xFF2C1800), Color(0xFF8B3A00)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative background numeral
          Positioned(
            right: -10,
            bottom: -20,
            child: Text(
              '24/7',
              style: TextStyle(
                fontSize: 150,
                fontWeight: FontWeight.w900,
                color: Colors.white.withAlpha(12),
                height: 1,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo row
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'M',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MAAT Kiosk',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: AppColors.textOnDark),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Welcome back',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check in for a class',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: AppColors.textOnDark,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Class List ────────────────────────────────────────────────────────────────

class _ClassList extends StatelessWidget {
  const _ClassList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();

    if (provider.isLoadingClasses) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.classesStatus == LoadStatus.error) {
      return SliverFillRemaining(
        child: _EmptyOrError(
          icon: Icons.wifi_off_rounded,
          title: 'Connection error',
          subtitle: provider.errorMessage ?? 'Could not load classes.',
        ),
      );
    }

    final classes = provider.todaysClasses;

    if (classes.isEmpty) {
      return const SliverFillRemaining(
        child: _EmptyOrError(
          icon: Icons.calendar_today_outlined,
          title: 'No classes today',
          subtitle: 'Check back later or contact reception.',
        ),
      );
    }

    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      sliver: SliverList.separated(
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final fc = classes[index];
          return ClassCard(
            fitnessClass: fc,
            onTap: () => Navigator.of(context)
                .pushNamed(AppRouter.classDetail, arguments: fc),
          );
        },
      ),
    );
  }
}

class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
