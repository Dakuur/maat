import 'package:flutter/material.dart';

/// Animates [child] in with a combined fade + upward-slide entrance.
///
/// Use [index] to create staggered effects in lists: each item waits
/// `index × staggerMs` milliseconds before starting its animation.
///
/// All transforms run on the GPU via [FadeTransition] + [SlideTransition]
/// (no setState / no paint calls during animation).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.staggerMs = 30,
  });

  /// The widget to animate in.
  final Widget child;

  /// Position in the list — drives the stagger delay.
  final int index;

  /// Milliseconds between each item's start time.
  final int staggerMs;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    // Opacity: easeOut feels instant at 144 fps.
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Slide: 4% upward → minimal displacement, avoids content feeling far away.
    _slide = Tween(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    // Cap stagger at the 5th item so items deeper in the list appear immediately
    // when the user scrolls — no visible empty gaps.
    final cappedIndex = widget.index.clamp(0, 5);
    final delay = Duration(milliseconds: cappedIndex * widget.staggerMs);
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
