import 'package:flutter_test/flutter_test.dart';
import 'package:lunch_map/core/bootstrap/startup_config.dart';

void main() {
  group('StartupConfig', () {
    test('requires Supabase URL', () {
      expect(
        () => StartupConfig.fromEnvironment(
          {
            'SUPABASE_ANON_KEY': 'anon',
            'NAVER_MAP_CLIENT_ID': 'naver',
          },
          requireNaverMapClientId: true,
        ),
        throwsA(
          isA<StartupConfigurationException>().having(
            (e) => e.missingKeys,
            'missingKeys',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('requires Supabase anon key', () {
      expect(
        () => StartupConfig.fromEnvironment(
          {
            'SUPABASE_URL': 'https://example.supabase.co',
            'NAVER_MAP_CLIENT_ID': 'naver',
          },
          requireNaverMapClientId: true,
        ),
        throwsA(
          isA<StartupConfigurationException>().having(
            (e) => e.missingKeys,
            'missingKeys',
            contains('SUPABASE_ANON_KEY'),
          ),
        ),
      );
    });

    test('requires Naver Map client ID for mobile map startup', () {
      expect(
        () => StartupConfig.fromEnvironment(
          {
            'SUPABASE_URL': 'https://example.supabase.co',
            'SUPABASE_ANON_KEY': 'anon',
          },
          requireNaverMapClientId: true,
        ),
        throwsA(
          isA<StartupConfigurationException>().having(
            (e) => e.missingKeys,
            'missingKeys',
            contains('NAVER_MAP_CLIENT_ID'),
          ),
        ),
      );
    });

    test('does not require Naver Map client ID outside mobile map startup', () {
      final config = StartupConfig.fromEnvironment(
        {
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_ANON_KEY': 'anon',
        },
        requireNaverMapClientId: false,
      );

      expect(config.supabaseUrl, 'https://example.supabase.co');
      expect(config.supabaseAnonKey, 'anon');
      expect(config.naverMapClientId, isNull);
    });

    test('trims valid configuration values', () {
      final config = StartupConfig.fromEnvironment(
        {
          'SUPABASE_URL': ' https://example.supabase.co ',
          'SUPABASE_ANON_KEY': ' anon ',
          'NAVER_MAP_CLIENT_ID': ' naver ',
        },
        requireNaverMapClientId: true,
      );

      expect(config.supabaseUrl, 'https://example.supabase.co');
      expect(config.supabaseAnonKey, 'anon');
      expect(config.naverMapClientId, 'naver');
    });
  });
}
