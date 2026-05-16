import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/location.dart';

/// Supabase 기반 장소 데이터 서비스
///
/// `coords` 컬럼은 DB 트리거가 lat/lng 로부터 자동 계산한다. 클라이언트에서
/// `'POINT(...)'` 문자열을 보내면 geography 캐스팅 오류가 발생할 수 있어
/// 더 이상 직접 전송하지 않는다.
class LocationService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _tableName = 'locations';

  static Future<List<Location>> getAll() async {
    final response = await _client
        .from(_tableName)
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((j) => Location.fromJson(j)).toList();
  }

  static Future<List<Location>> getUnfixed() async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('is_fixed', false)
        .order('created_at', ascending: false);
    return (response as List).map((j) => Location.fromJson(j)).toList();
  }

  static Future<List<Location>> getFixed() async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('is_fixed', true)
        .order('created_at', ascending: false);
    return (response as List).map((j) => Location.fromJson(j)).toList();
  }

  static Future<Location?> getById(String id) async {
    final response =
        await _client.from(_tableName).select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return Location.fromJson(response);
  }

  static Future<Location> insert(Location location) async {
    final data = location.toJson();
    final response =
        await _client.from(_tableName).insert(data).select().single();
    return Location.fromJson(response);
  }

  static Future<Location> update(String id, Location location) async {
    final response = await _client
        .from(_tableName)
        .update(location.toJson())
        .eq('id', id)
        .select()
        .single();
    return Location.fromJson(response);
  }

  /// 기본 정보(이름·전화번호) 업데이트.
  /// 빈 문자열로 보내면 해당 컬럼을 NULL 로 비운다.
  static Future<Location> updateInfo(
    String id, {
    required String name,
    String? phone,
  }) async {
    final patch = <String, dynamic>{
      'name': name,
      'phone': (phone == null || phone.isEmpty) ? null : phone,
    };
    final response = await _client
        .from(_tableName)
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Location.fromJson(response);
  }

  /// 위치 좌표 업데이트 — coords 는 트리거가 갱신한다.
  static Future<Location> updateCoordinates(
    String id, {
    required double lat,
    required double lng,
  }) async {
    final response = await _client
        .from(_tableName)
        .update({
          'lat': lat,
          'lng': lng,
          'is_fixed': true,
        })
        .eq('id', id)
        .select()
        .single();
    return Location.fromJson(response);
  }

  static Future<void> delete(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }

  static Future<List<Location>> search(String query) async {
    final response = await _client
        .from(_tableName)
        .select()
        .ilike('name', '%$query%')
        .order('created_at', ascending: false);
    return (response as List).map((j) => Location.fromJson(j)).toList();
  }

  /// 통계 — 단일 쿼리로 가져와 클라이언트에서 집계한다.
  /// (이전 버전은 세 번 쿼리해 0건 표시 등 race 문제가 보고됨)
  static Future<Map<String, int>> getStats() async {
    final rows = await _client.from(_tableName).select('is_fixed');
    final list = rows as List;
    var fixed = 0;
    for (final row in list) {
      if ((row as Map)['is_fixed'] == true) fixed++;
    }
    return {
      'total': list.length,
      'fixed': fixed,
      'unfixed': list.length - fixed,
    };
  }
}
