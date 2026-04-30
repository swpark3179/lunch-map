import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class LunchMapApp extends StatelessWidget {
  const LunchMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '점심 지도 - Lunch Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
