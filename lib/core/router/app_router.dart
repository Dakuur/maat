import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../data/models/fitness_class.dart';
import '../../data/models/member.dart';
import '../../presentation/screens/checkin_confirm/checkin_confirm_screen.dart';
import '../../presentation/screens/class_detail/class_detail_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/member_search/member_search_screen.dart';
import '../../presentation/screens/success/success_screen.dart';

/// Central routing configuration.
///
/// All transitions use [SharedAxisTransition] (horizontal axis) from the
/// Material Motion spec. This gives a polished shared-element feel — the
/// outgoing screen slides left while fading out as the incoming one slides
/// in from the right — and runs at the device's native refresh rate.
abstract final class AppRouter {
  static const String home = '/';
  static const String classDetail = '/class-detail';
  static const String memberSearch = '/member-search';
  static const String checkinConfirm = '/checkin-confirm';
  static const String success = '/success';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _sharedAxis(const HomeScreen(), settings);

      case classDetail:
        final fc = settings.arguments as FitnessClass;
        return _sharedAxis(ClassDetailScreen(fitnessClass: fc), settings);

      case memberSearch:
        final fc = settings.arguments as FitnessClass;
        return _sharedAxis(MemberSearchScreen(fitnessClass: fc), settings);

      case checkinConfirm:
        final args = settings.arguments as Map<String, dynamic>;
        return _sharedAxis(
          CheckInConfirmScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
        );

      case success:
        final args = settings.arguments as Map<String, dynamic>;
        // Use a vertical scale transition for the success screen to feel
        // celebratory and distinct from normal forward navigation.
        return _sharedAxis(
          SuccessScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
          type: SharedAxisTransitionType.scaled,
        );

      default:
        return _sharedAxis(const HomeScreen(), settings);
    }
  }

  /// Builds a [SharedAxisTransition] page route.
  ///
  /// [type] defaults to [SharedAxisTransitionType.horizontal] for the standard
  /// forward/back navigation feel. Use [SharedAxisTransitionType.scaled] for
  /// modal or confirmation destinations.
  static PageRouteBuilder<T> _sharedAxis<T>(
    Widget page,
    RouteSettings settings, {
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          // Disable the fill-color so it composites cleanly on any background.
          fillColor: Colors.transparent,
          child: child,
        );
      },
    );
  }
}
