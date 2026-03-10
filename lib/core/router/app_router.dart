import 'package:flutter/material.dart';

import '../../data/models/fitness_class.dart';
import '../../data/models/member.dart';
import '../../presentation/screens/checkin_confirm/checkin_confirm_screen.dart';
import '../../presentation/screens/class_detail/class_detail_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/member_search/member_search_screen.dart';
import '../../presentation/screens/success/success_screen.dart';

abstract final class AppRouter {
  static const String home = '/';
  static const String classDetail = '/class-detail';
  static const String memberSearch = '/member-search';
  static const String checkinConfirm = '/checkin-confirm';
  static const String success = '/success';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _slide(const HomeScreen(), settings);

      case classDetail:
        final fc = settings.arguments as FitnessClass;
        return _slide(ClassDetailScreen(fitnessClass: fc), settings);

      case memberSearch:
        final fc = settings.arguments as FitnessClass;
        return _slide(MemberSearchScreen(fitnessClass: fc), settings);

      case checkinConfirm:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(
          CheckInConfirmScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
        );

      case success:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(
          SuccessScreen(
            member: args['member'] as Member,
            fitnessClass: args['fitnessClass'] as FitnessClass,
          ),
          settings,
        );

      default:
        return _slide(const HomeScreen(), settings);
    }
  }

  static PageRouteBuilder<T> _slide<T>(
      Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const curve = Curves.easeInOutCubic;
        final tween =
            Tween(begin: begin, end: Offset.zero).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}
