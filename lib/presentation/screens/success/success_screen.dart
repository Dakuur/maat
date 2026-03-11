import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/checked_in_person.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/checkin_provider.dart';

// ── Success screen ──────────────────────────────────────────────────────────────
//
// Accepts a list of [CheckedInPerson] so it works for:
//   - Single check-in   → one avatar centred
//   - Bulk check-in     → row of avatars (max 4 shown + "+N" chip)
//   - Self (Google user)→ one avatar from OAuth profile photo
//
// Animation sequence:
//   t=0      Fireworks burst + entrance (check icon + avatars fade+scale in)
//   t=200ms  Timer ring starts shrinking 200 px → 80 px over 5 s
//   t=650ms  Entrance done → avatars start bobbing with staggered sine phases
//   t=5200ms Auto-redirect to Home

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.people,
    required this.fitnessClass,
  });

  final List<CheckedInPerson> people;
  final FitnessClass fitnessClass;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {

  // Entrance: check icon + avatars pop in together
  late final AnimationController _entranceCtrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;

  // Continuous sine-wave bob for the avatar cluster.
  // Value goes 0→1→0→1… (repeat), each avatar uses a different phase offset
  // so they bob independently like buoys on water.
  late final AnimationController _floatCtrl;

  // Fireworks burst (one-shot, 1.8 s)
  late final AnimationController _fireworksCtrl;

  // Timer ring shrinks 200 px → 80 px over 5 s
  late final AnimationController _timerCtrl;
  late final Animation<double> _circleSize;

  @override
  void initState() {
    super.initState();

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

    // Full 2-second sine cycle — no reverse, so sin(value * 2π) = clean wave.
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fireworksCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _timerCtrl = AnimationController(
      vsync: this,
      duration: AppConstants.successRedirectDelay,
    );
    _circleSize = Tween<double>(begin: 200.0, end: 80.0).animate(
      CurvedAnimation(parent: _timerCtrl, curve: Curves.linear),
    );

    HapticFeedback.heavyImpact();

    // Entrance first; avatar bob loop starts when entrance completes.
    _entranceCtrl.forward().whenComplete(() {
      if (mounted) _floatCtrl.repeat();
    });
    _fireworksCtrl.forward();
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
    _floatCtrl.dispose();
    _fireworksCtrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  // ── Headline body text ──────────────────────────────────────────────────────

  String get _bodyText {
    final cls = widget.fitnessClass.name;
    final p = widget.people;
    if (p.length == 1) {
      return '${p.first.firstName}, you\'re checked in\nfor $cls.';
    }
    if (p.length == 2) {
      return '${p[0].firstName} & ${p[1].firstName} are\nchecked in for $cls.';
    }
    return '${p.length} members checked in\nfor $cls.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fireworks layer
          AnimatedBuilder(
            animation: _fireworksCtrl,
            builder: (_, __) => CustomPaint(
              painter: _FireworksPainter(_fireworksCtrl.value),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // MAAT logo
                  Image.asset(
                    'assets/maat-logo-inverted.png',
                    width: 64,
                    height: 64,
                  ),

                  const SizedBox(height: 28),

                  // Floating avatar cluster — fades in with the check icon,
                  // then each avatar bobs at its own phase offset.
                  FadeTransition(
                    opacity: _checkFade,
                    child: _AvatarCluster(
                      people: widget.people,
                      floatCtrl: _floatCtrl,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Timer ring + check icon
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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

                  const SizedBox(height: 24),

                  FadeTransition(
                    opacity: _checkFade,
                    child: Text(
                      "You're in!",
                      style: theme.textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 10),

                  FadeTransition(
                    opacity: _checkFade,
                    child: Text(
                      _bodyText,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Countdown text — ticks down in real time
                  AnimatedBuilder(
                    animation: _timerCtrl,
                    builder: (_, __) {
                      final secs =
                          ((1.0 - _timerCtrl.value) * 5).ceil().clamp(0, 5);
                      return Text(
                        'Returning to menu in $secs second${secs == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textTertiary),
                        textAlign: TextAlign.center,
                      );
                    },
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

// ── Avatar cluster ─────────────────────────────────────────────────────────────
//
// Renders 1–4 avatars in a horizontal row; avatars beyond 4 are collapsed
// into a "+N" chip. Each avatar bobs on an independent sine phase so they
// move like buoys rather than a single rigid block.

class _AvatarCluster extends StatelessWidget {
  const _AvatarCluster({
    required this.people,
    required this.floatCtrl,
  });

  final List<CheckedInPerson> people;
  final AnimationController floatCtrl;

  static const int _maxDisplay = 4;

  // Avatar diameter scales down as the group grows so the row fits the screen.
  static double _size(int count) {
    if (count == 1) return 88;
    if (count == 2) return 74;
    if (count <= 4) return 62;
    return 54;
  }

  @override
  Widget build(BuildContext context) {
    final display = people.take(_maxDisplay).toList();
    final extra = people.length - _maxDisplay;
    final size = _size(people.length);
    final total = display.length + (extra > 0 ? 1 : 0);

    return AnimatedBuilder(
      animation: floatCtrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < display.length; i++) ...[
              if (i > 0) SizedBox(width: size * 0.15),
              Transform.translate(
                // Spread phases evenly across 2π so no two avatars bob in sync.
                offset: Offset(
                  0,
                  sin(floatCtrl.value * 2 * pi +
                          (i / total) * 2 * pi) *
                      6,
                ),
                child: _PersonAvatar(person: display[i], size: size),
              ),
            ],
            if (extra > 0) ...[
              SizedBox(width: size * 0.15),
              Transform.translate(
                offset: Offset(
                  0,
                  sin(floatCtrl.value * 2 * pi +
                          (display.length / total) * 2 * pi) *
                      6,
                ),
                child: _ExtraChip(count: extra, size: size),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Single person avatar (ring + photo or initials) ───────────────────────────

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.person, required this.size});

  final CheckedInPerson person;
  final double size;

  String get _initials {
    final parts = person.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return person.name.isNotEmpty ? person.name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.success.withAlpha(140),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withAlpha(40),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: ClipOval(
          child: person.photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: person.photoUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _initialsWidget(),
                )
              : _initialsWidget(),
        ),
      ),
    );
  }

  Widget _initialsWidget() {
    // Deterministic colour from name hash — same palette as MemberAvatar.
    const palette = [
      Color(0xFFE87D3E),
      Color(0xFF30A046),
      Color(0xFF0066CC),
      Color(0xFFD70015),
      Color(0xFF4B44C8),
    ];
    final color = palette[person.name.hashCode.abs() % palette.length];
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── "+N more" chip ────────────────────────────────────────────────────────────

class _ExtraChip extends StatelessWidget {
  const _ExtraChip({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: size * 0.28,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Fireworks painter ──────────────────────────────────────────────────────────

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.progress);
  final double progress;

  static final List<_BurstConfig> _bursts = _buildBursts();

  static List<_BurstConfig> _buildBursts() {
    final rng = Random(42);
    const colors = [
      Color(0xFF34C759),
      Color(0xFF64D2FF),
      Color(0xFFFFD60A),
      Color(0xFFFF9F0A),
      Color(0xFFBF5AF2),
      Color(0xFFFF6B6B),
      Color(0xFF5AC8FA),
      Color(0xFF30D158),
    ];
    return List.generate(8, (i) {
      final angle = (i / 8) * 2 * pi + rng.nextDouble() * 0.6;
      final r = 0.15 + rng.nextDouble() * 0.20;
      return _BurstConfig(
        dxNorm: cos(angle) * r,
        dyNorm: sin(angle) * r,
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
    for (final b in _bursts) {
      final local =
          ((progress - b.delay) / (1.0 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dist = b.spreadRadius * (1 - (1 - local) * (1 - local));
      final opacity =
          local < 0.25 ? local / 0.25 : 1.0 - ((local - 0.25) / 0.75) * ((local - 0.25) / 0.75);
      if (opacity <= 0) continue;
      final paint = Paint()
        ..color = b.color.withAlpha((opacity * 200).round())
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final bx = cx + b.dxNorm * size.width;
      final by = cy + b.dyNorm * size.height;
      for (int i = 0; i < b.particleCount; i++) {
        final a = (i / b.particleCount) * 2 * pi;
        final hx = bx + cos(a) * dist;
        final hy = by + sin(a) * dist;
        final tail = b.lineLength * (1.0 - local * 0.4) * opacity;
        canvas.drawLine(
          Offset(hx - cos(a) * tail, hy - sin(a) * tail),
          Offset(hx, hy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter o) => o.progress != progress;
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
  final double dxNorm, dyNorm, delay;
  final int particleCount;
  final Color color;
  final double spreadRadius, lineLength;
}
