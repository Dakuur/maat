import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/firebase_service.dart';
import 'presentation/providers/checkin_provider.dart';
import 'presentation/providers/class_provider.dart';

class MaatKioskApp extends StatelessWidget {
  const MaatKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ClassProvider(FirebaseService.instance),
        ),
        ChangeNotifierProvider(
          create: (_) => CheckInProvider(FirebaseService.instance),
        ),
      ],
      child: MaterialApp(
        title: 'MAAT Kiosk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
