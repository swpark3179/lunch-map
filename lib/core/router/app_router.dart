import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/location_list/location_list_screen.dart';
import '../../features/map_picker/map_picker_screen.dart';
import '../../features/excel_upload/excel_upload_screen.dart';
import '../../features/location_detail/location_detail_screen.dart';
import '../shell/app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/locations',
          name: 'locations',
          builder: (context, state) => const LocationListScreen(),
        ),
        GoRoute(
          path: '/location/:id',
          name: 'location-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return LocationDetailScreen(locationId: id);
          },
        ),
        GoRoute(
          path: '/map-picker',
          name: 'map-picker',
          builder: (context, state) {
            final locationId = state.uri.queryParameters['locationId'];
            return MapPickerScreen(locationId: locationId);
          },
        ),
        GoRoute(
          path: '/upload',
          name: 'upload',
          builder: (context, state) => const ExcelUploadScreen(),
        ),
      ],
    ),
  ],
);
