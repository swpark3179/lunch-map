import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/location.dart';

/// Supabase 기반 장소 데이터 서비스
class LocationService {
  static final _client = Supabase.instance.client;
  static const _tableName = 'locations';

  /// 전체 장소 목록 조회
  static Future<List<Location>> getAll() async {
    final response = await _client
        .from(_tableName)
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  /// 위치 미확정 장소만 조회
  static Future<List<Location>> getUnfixed() async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('is_fixed', false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  /// 위치 확정 장소만 조회
  static Future<List<Location>> getFixed() async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('is_fixed', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  /// 단일 장소 조회
  static Future<Location?> getById(String id) async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Location.fromJson(response);
  }

  /// 장소 추가
  static Future<Location> insert(Location location) async {
    final data = location.toJson();
    final response = await _client
        .from(_tableName)
        .insert(data)
        .select()
        .single();

    return Location.fromJson(response);
  }

  /// 장소 일괄 추가 (엑셀 업로드용)
  static Future<List<Location>> insertBatch(List<Location> locations) async {
    final data = locations.map((l) => l.toJson()).toList();
    final response = await _client
        .from(_tableName)
        .insert(data)
        .select();

    return (response as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  /// 장소 업데이트
  static Future<Location> update(String id, Location location) async {
    final data = location.toJson();
    final response = await _client
        .from(_tableName)
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return Location.fromJson(response);
  }

  /// 위치 좌표 업데이트 (지도 등록용)
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
          'coords': 'POINT($lng $lat)',
          'is_fixed': true,
        })
        .eq('id', id)
        .select()
        .single();

    return Location.fromJson(response);
  }

  /// 장소 삭제
  static Future<void> delete(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }

  /// 장소 검색 (이름 기반)
  static Future<List<Location>> search(String query) async {
    final response = await _client
        .from(_tableName)
        .select()
        .ilike('name', '%$query%')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Location.fromJson(json))
        .toList();
  }

  /// 통계 정보 조회
  static Future<Map<String, int>> getStats() async {
    final totalResponse = await _client.from(_tableName).select(
          'id',
          const FetchOptions(count: CountOption.exact, head: true),
        );

    final fixedResponse = await _client
        .from(_tableName)
        .select(
          'id',
          const FetchOptions(count: CountOption.exact, head: true),
        )
        .eq('is_fixed', true);

    final unfixedResponse = await _client
        .from(_tableName)
        .select(
          'id',
          const FetchOptions(count: CountOption.exact, head: true),
        )
        .eq('is_fixed', false);

    return {
      'total': totalResponse.count ?? 0,
      'fixed': fixedResponse.count ?? 0,
      'unfixed': unfixedResponse.count ?? 0,
    };
  }
}
