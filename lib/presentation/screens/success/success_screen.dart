import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../data/models/member.dart';
import '../../../presentation/providers/checkin_provider.dart';

// ── Success screen ─────────────────────────────────────────────────────────────

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
    with TickerProviderStateMixin {
  // ── Entrance animation (check icon) ────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  // ── Fireworks (one-shot, 1.8 s) ────────────────────────────────────────────
  late final AnimationController _fireworksCtrl;

  // ── Timer circle (shrinks 200 px → 80 px over 5 s) ─────────────────────────
  late final AnimationController _timerCtrl;
  late final Animation<double> _circleSize;

  @override
  void initState() {
    super.initState();

    // ── Entrance ─────────────────────────────────────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut),
    );

    _checkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    // ── Fireworks ─────────────────────────────────────────────────────────────
    _fireworksCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // ── Timer circle ─────────────────────────────────────────────────────────
    // Shrinks linearly from 200 px to 80 px (= icon size) over 5 s.
    // When it completes it sits right at the icon edge, then auto-reset fires.
    _timerCtrl = AnimationController(
      vsync: this,
      duration: AppConstants.successRedirectDelay,
    );

    _circleSize = Tween<double>(begin: 200.0, end: 80.0).animate(
      CurvedAnimation(parent: _timerCtrl, curve: Curves.linear),
    );

    // ── Sequence ──────────────────────────────────────────────────────────────
    HapticFeedback.heavyImpact();
    _entranceCtrl.forward();
    _fireworksCtrl.forward();

    // Give the entrance a small head-start before the circle begins counting.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _timerCtrl.forward().whenComplete(() {
        if (mounted) _goHome();
      });
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
    _entranceCtrl.dispose();
    _fireworksCtrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fireworks layer ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _fireworksCtrl,
            builder: (_, __) => CustomPaint(
              painter: _FireworksPainter(_fireworksCtrl.value),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset('assets/maat-logo-inverted.png', width: 64, height: 64),

                  const Spacer(),

                  // ── Timer circle + check icon ─────────────────────────
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shrinking ring (visual timer)
                        AnimatedBuilder(
                          animation: _timerCtrl,
                          builder: (_, __) => SizedBox(
                            width: _circleSize.value,
                            height: _circleSize.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.success.withAlpha(90),
                                  width: 1.5,
                                ),
                                color: AppColors.success.withAlpha(12),
                              ),
                            ),
                          ),
                        ),

                        // Check icon
                        FadeTransition(
                          opacity: _checkFade,
                          child: ScaleTransition(
                            scale: _checkScale,
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 80,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  FadeTransition(
                    opacity: _checkFade,
                    child: Text(
                      "You're in!",
                      style: theme.textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  FadeTransition(
                    opacity: _checkFade,
                    child: Text(
                      '${widget.member.firstName}, you\'re checked in\n'
                      'for ${widget.fitnessClass.name}.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Spacer(),

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

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fireworks painter ──────────────────────────────────────────────────────────

/// Paints minimalist burst animations: thin lines radiate from several
/// staggered focal points, fade in quickly, then dissolve.
class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.progress);

  final double progress; // 0.0 → 1.0

  // Fixed seed → deterministic layout every time.
  static final List<_BurstConfig> _bursts = _buildBursts();

  static List<_BurstConfig> _buildBursts() {
    final rng = Random(42);
    // Soft, muted palette — avoids neon / overly saturated tones.
    const colors = [
      Color(0xFF34C759), // success green
      Color(0xFF64D2FF), // sky blue
      Color(0xFFFFD60A), // golden yellow
      Color(0xFFFF9F0A), // amber
      Color(0xFFBF5AF2), // soft purple
      Color(0xFFFF6B6B), // coral
      Color(0xFF5AC8FA), // light blue
      Color(0xFF30D158), // mint
    ];

    return List.generate(8, (i) {
      // Distribute bursts in a loose ring around centre.
      final angle = (i / 8) * 2 * pi + rng.nextDouble() * 0.6;
      final radiusNorm = 0.15 + rng.nextDouble() * 0.20;
      return _BurstConfig(
        dxNorm: cos(angle) * radiusNorm,
        dyNorm: sin(angle) * radiusNorm,
        // Stagger: bursts start between 0 % and 35 % of the animation.
        delay: i * 0.04 + rng.nextDouble() * 0.05,
        particleCount: 8 + rng.nextInt(5),
        color: colors[i % colors.length],
        spreadRadius: 36 + rng.nextDouble() * 28,
        lineLength: 6 + rng.nextDouble() * 8,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final burst in _bursts) {
      // Normalise progress to this burst's local timeline.
      final local =
          ((progress - burst.delay) / (1.0 - burst.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Ease-out radial expansion.
      final dist = burst.spreadRadius * _easeOut(local);

      // Opacity: fade in for first 25 % of local time, then fade out.
      final opacity =
          local < 0.25 ? local / 0.25 : 1.0 - _easeIn((local - 0.25) / 0.75);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = burst.color.withAlpha((opacity * 200).round())
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final bx = cx + burst.dxNorm * size.width;
      final by = cy + burst.dyNorm * size.height;

      for (int i = 0; i < burst.particleCount; i++) {
        final pAngle = (i / burst.particleCount) * 2 * pi;
        final headX = bx + cos(pAngle) * dist;
        final headY = by + sin(pAngle) * dist;

        // Tail fades behind the head as the particle moves outward.
        final tail = burst.lineLength * (1.0 - local * 0.4) * opacity;
        final tailX = headX - cos(pAngle) * tail;
        final tailY = headY - sin(pAngle) * tail;

        canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), paint);
      }
    }
  }

  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  static double _easeIn(double t) => t * t;

  @override
  bool shouldRepaint(_FireworksPainter old) => old.progress != progress;
}

class _BurstConfig {
  const _BurstConfig({
    required this.dxNorm,
    required this.dyNorm,
    required this.delay,
    required this.particleCount,
    required this.color,
    required this.spreadRadius,
    required this.lineLength,
  });

  /// Position relative to screen centre, normalised by screen half-width/height.
  final double dxNorm;
  final double dyNorm;

  /// Normalised delay before this burst starts (0.0 – 0.35).
  final double delay;

  final int particleCount;
  final Color color;

  /// Maximum distance a particle travels from the burst origin (px).
  final double spreadRadius;

  /// Comet-tail length at peak opacity (px).
  final double lineLength;
}
