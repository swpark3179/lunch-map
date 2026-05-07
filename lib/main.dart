import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/bootstrap/startup_config.dart';
import 'core/bootstrap/startup_failure_app.dart';

export 'app.dart' show LunchMapApp, MyApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startupFailure = await _initializeStartupServices();
  if (startupFailure != null) {
    runApp(StartupFailureApp(failure: startupFailure));
    return;
  }

  runApp(const ProviderScope(child: LunchMapApp()));
}

Future<StartupFailure?> _initializeStartupServices() async {
  try {
    await dotenv.load(fileName: '.env');

    final requiresNaverMap = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final config = StartupConfig.fromEnvironment(
      dotenv.env,
      requireNaverMapClientId: requiresNaverMap,
    );

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );

    if (requiresNaverMap) {
      await FlutterNaverMap().init(
        clientId: config.naverMapClientId,
        onAuthFailed: (ex) {
          debugPrint('[NaverMap] auth failed: $ex');
        },
      );
    }

    return null;
  } on StartupConfigurationException catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'startup',
        context: ErrorDescription('validating startup configuration'),
      ),
    );
    return StartupFailure(
      title: 'Startup configuration is incomplete',
      detail: error.message,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'startup',
        context: ErrorDescription('initializing startup services'),
      ),
    );
    return StartupFailure(
      title: 'Lunch Map could not start',
      detail: 'Startup services failed to initialize. Check the device logs for '
          'the detailed startup error.',
    );
  }
}
