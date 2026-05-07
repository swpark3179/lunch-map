class StartupConfigurationException implements Exception {
  final List<String> missingKeys;

  const StartupConfigurationException(this.missingKeys);

  String get message =>
      'Missing required startup configuration: ${missingKeys.join(', ')}';

  @override
  String toString() => message;
}

class StartupConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? naverMapClientId;

  const StartupConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.naverMapClientId,
  });

  factory StartupConfig.fromEnvironment(
    Map<String, String?> environment, {
    required bool requireNaverMapClientId,
  }) {
    final missing = <String>[];

    String readRequired(String key) {
      final value = environment[key]?.trim();
      if (value == null || value.isEmpty) {
        missing.add(key);
        return '';
      }
      return value;
    }

    final supabaseUrl = readRequired('SUPABASE_URL');
    final supabaseAnonKey = readRequired('SUPABASE_ANON_KEY');
    final naverMapClientId = environment['NAVER_MAP_CLIENT_ID']?.trim();

    if (requireNaverMapClientId &&
        (naverMapClientId == null || naverMapClientId.isEmpty)) {
      missing.add('NAVER_MAP_CLIENT_ID');
    }

    if (missing.isNotEmpty) {
      throw StartupConfigurationException(missing);
    }

    return StartupConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      naverMapClientId:
          naverMapClientId == null || naverMapClientId.isEmpty
              ? null
              : naverMapClientId,
    );
  }
}
