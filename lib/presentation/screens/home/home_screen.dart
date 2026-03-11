import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/calendar_provider.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/class_card.dart';
import '../../../presentation/widgets/fade_slide_in.dart';

const _merchUrl = 'https://www.aranhabarcelona.com/';

const _trainingPlans = [
  'Unlimited',
  '3x / week',
  '2x / week',
  '1x / week',
  'Drop-in',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _planDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().watchTodaysClasses();
      // Listen directly to AuthProvider so we catch changes that happen
      // after the first build (e.g. sign-in completing asynchronously).
      context.read<AuthProvider>().addListener(_onAuthChanged);
      _maybeShowPlanDialog();
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _maybeShowPlanDialog();
    _syncMyCheckIns();
  }

  void _syncMyCheckIns() {
    final auth = context.read<AuthProvider>();
    final cp = context.read<ClassProvider>();
    final cal = context.read<CalendarProvider>();
    if (auth.isLoggedIn) {
      final memberId = 'user:${auth.user!.uid}';
      cp.watchMyCheckIns(memberId);
      cal.setUserMemberId(memberId);
    } else {
      cp.stopWatchingMyCheckIns();
      cal.setUserMemberId(null);
    }
  }

  void _maybeShowPlanDialog() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.needsTrainingPlan && !_planDialogShown) {
      _planDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTrainingPlanDialog();
      });
    }
    // Reset flag when user logs out so it shows again on next sign-in
    if (!auth.isLoggedIn) _planDialogShown = false;
  }

  void _showTrainingPlanDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TrainingPlanDialog(),
    ).then((_) => _planDialogShown = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<ClassProvider>().watchTodaysClasses();
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              padding: EdgeInsets.only(top: 20),
              sliver: _ClassList(),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.sectionSpacing,
                AppConstants.pagePadding,
                40,
              ),
              sliver: SliverToBoxAdapter(child: _MerchBanner()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Training Plan Dialog ───────────────────────────────────────────────────────

class _TrainingPlanDialog extends StatefulWidget {
  const _TrainingPlanDialog();

  @override
  State<_TrainingPlanDialog> createState() => _TrainingPlanDialogState();
}

class _TrainingPlanDialogState extends State<_TrainingPlanDialog> {
  String? _selected;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Your Training Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How often do you train?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trainingPlans
                .map(
                  (plan) => ChoiceChip(
                    label: Text(plan),
                    selected: _selected == plan,
                    onSelected: (_) => setState(() => _selected = plan),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _selected == null || _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await context
                      .read<AuthProvider>()
                      .setTrainingPlan(_selected!);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
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
    final bannerHeight = 220 + MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();

    return Container(
      height: bannerHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151515), Color(0xFF2C1800), Color(0xFF8B3A00)],
        ),
      ),
      child: Stack(
        children: [
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
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo row + auth button
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/maat-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MAAT Kiosk',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: AppColors.textOnDark),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRouter.calendar),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AuthButton(auth: auth),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    auth.isLoggedIn
                        ? 'Welcome back, ${auth.user!.displayName.split(' ').first}'
                        : 'Welcome back',
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

// ── Auth Button ───────────────────────────────────────────────────────────────

class _AuthButton extends StatelessWidget {
  const _AuthButton({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    if (auth.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    if (auth.isLoggedIn) {
      return GestureDetector(
        onTap: () => _showUserMenu(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 1.5),
          ),
          child: ClipOval(
            child: auth.user!.photoUrl != null
                ? Image.network(
                    auth.user!.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initials(context),
                  )
                : _initials(context),
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
      icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
      label: const Text(
        'Sign in',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: Colors.white.withAlpha(25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _initials(BuildContext context) {
    final name = auth.user!.displayName;
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';
    return ColoredBox(
      color: AppColors.warning,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (user.trainingPlan != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Plan: ${user.trainingPlan}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<AuthProvider>().signOut();
                },
              ),
            ],
          ),
        ),
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

    final myClassIds = provider.myJoinedClassIds;

    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      sliver: SliverList.separated(
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final fc = classes[index];
          return FadeSlideIn(
            index: index,
            child: ClassCard(
              fitnessClass: fc,
              isJoined: myClassIds.contains(fc.id),
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRouter.classDetail, arguments: fc),
            ),
          );
        },
      ),
    );
  }
}

// ── Merch Banner ──────────────────────────────────────────────────────────────

class _MerchBanner extends StatelessWidget {
  const _MerchBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(_merchUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF8B1A00),
                      Color(0xFF2C1800),
                      Color(0xFF151515),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -12,
                bottom: -24,
                child: Text(
                  'STORE',
                  style: TextStyle(
                    fontSize: 110,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withAlpha(10),
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPERIENCE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Aranha x MAAT Store',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Roll more, learn more, sweat more.\nSummer starts at the mat.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
