import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../data/models/member.dart';
import '../../../presentation/providers/checkin_provider.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.member,
    required this.fitnessClass,
  });

  final Member member;
  final FitnessClass fitnessClass;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  int _countdown = AppConstants.successRedirectDelay.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.easeIn)),
    );

    _ctrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _goHome();
      }
    });
  }

  void _goHome() {
    if (!mounted) return;
    context.read<CheckInProvider>().reset();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRouter.home, (_) => false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Animated check icon ─────────────────────────────────────
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 80,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              FadeTransition(
                opacity: _fade,
                child: Text(
                  "You're in!",
                  style: theme.textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              FadeTransition(
                opacity: _fade,
                child: Text(
                  '${widget.member.firstName}, you\'re checked in\nfor ${widget.fitnessClass.name}.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // ── Countdown ───────────────────────────────────────────────
              Column(
                children: [
                  Text(
                    'Returning to home in',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_countdown',
                    style: theme.textTheme.displayMedium
                        ?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              TextButton(
                onPressed: _goHome,
                child: Text(
                  'Back to Home',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.actionPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
