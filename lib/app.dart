import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/services/firebase_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/calendar_provider.dart';
import 'presentation/providers/checkin_provider.dart';
import 'presentation/providers/class_provider.dart';

class MaatKioskApp extends StatelessWidget {
  const MaatKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => ClassProvider(FirebaseService.instance),
        ),
        ChangeNotifierProvider(
          create: (_) => CheckInProvider(FirebaseService.instance),
        ),
        // CalendarProvider lives at app level so Google Calendar sync data
        // persists when the user navigates away and back to the calendar.
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: MaterialApp(
        title: 'MAAT Kiosk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Ensures the Navigator background is never the default black,
        // eliminating any flash when pushing/popping between routes.
        color: AppColors.surface,
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
