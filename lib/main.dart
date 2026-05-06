import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드
  await dotenv.load(fileName: '.env');

  // Supabase 초기화
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 네이버 지도는 Android와 iOS에서만 지원되므로 조건부 초기화
  // flutter_naver_map 1.3.1+부터 NaverMapSdk.instance.initialize는 Legacy로 deprecated.
  // 신규 FlutterNaverMap().init을 사용해야 앱이 정상 시작된다.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FlutterNaverMap().init(
      clientId: dotenv.env['NAVER_MAP_CLIENT_ID'],
      onAuthFailed: (ex) {
        debugPrint('[NaverMap] 인증 실패: $ex');
      },
    );
  }

  runApp(const ProviderScope(child: LunchMapApp()));
}
