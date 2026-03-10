import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/fitness_class.dart';
import '../../data/models/member.dart';
import '../../presentation/screens/checkin_confirm/checkin_confirm_screen.dart';
import '../../presentation/screens/class_detail/class_detail_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/member_search/member_search_screen.dart';
import '../../presentation/screens/success/success_screen.dart';

/// Central routing configuration.
///
/// All standard transitions use a cross-fade over a guaranteed white background
/// to eliminate the black flash that appears when [fillColor] is transparent.
/// The success screen uses a subtle scale + fade to feel celebratory.
abstract final class AppRouter {
  static const String home = '/';
  static const String classDetail = '/class-detail';
  static const String memberSearch = '/member-search';
  static const String checkinConfirm = '/checkin-confirm';
  static const String success = '/success';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _fadeRoute(const HomeScreen(), settings);

      case classDetail:
        final fc = settings.arguments as FitnessClass;
        return _fadeRoute(ClassDetailScreen(fitnessClass: fc), settings);

      case memberSearch:
        final fc = settings.arguments as FitnessClass;
        return _fadeRoute(MemberSearchScreen(fitnessClass: fc), settings);

      case checkinConfirm:
        final args = settings.arguments as Map<String, dynamic>;
        return _fadeRoute(
          CheckInConfirmScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
        );

      case success:
        final args = settings.arguments as Map<String, dynamic>;
        return _scaleRoute(
          SuccessScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
        );

      default:
        return _fadeRoute(const HomeScreen(), settings);
    }
  }

  /// Cross-fade with a solid white backing — no black flash.
  static PageRouteBuilder<T> _fadeRoute<T>(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      // ColoredBox ensures the white background is always painted
      // before the page content, preventing the Navigator's default
      // black background from bleeding through.
      pageBuilder: (_, __, ___) => ColoredBox(
        color: AppColors.surface,
        child: page,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  /// Scale-up + fade for the success / confirmation destination.
  static PageRouteBuilder<T> _scaleRoute<T>(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => ColoredBox(
        color: AppColors.surface,
        child: page,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
