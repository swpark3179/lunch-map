import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location.dart';
import '../../data/services/location_service.dart';

/// 장소 목록 상태
enum LocationFilter { all, fixed, unfixed }

/// 장소 목록 Provider
final locationListProvider =
    AsyncNotifierProvider<LocationListNotifier, List<Location>>(
      LocationListNotifier.new,
    );

/// 현재 필터 Provider
final locationFilterProvider = StateProvider<LocationFilter>(
  (ref) => LocationFilter.all,
);

/// 검색 쿼리 Provider
final locationSearchProvider = StateProvider<String>((ref) => '');

/// 통계 Provider — locationListProvider 데이터에서 파생 (별도 DB 쿼리 없음)
final locationStatsProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  return ref.watch(locationListProvider).whenData((list) => {
    'total': list.length,
    'fixed': list.where((l) => l.isFixed).length,
    'unfixed': list.where((l) => !l.isFixed).length,
  });
});

/// 필터링된 장소 목록 Provider
final filteredLocationListProvider = Provider<AsyncValue<List<Location>>>((
  ref,
) {
  final filter = ref.watch(locationFilterProvider);
  final search = ref.watch(locationSearchProvider);
  final locations = ref.watch(locationListProvider);

  return locations.whenData((list) {
    var filtered = list;

    // 필터 적용
    switch (filter) {
      case LocationFilter.fixed:
        filtered = filtered.where((l) => l.isFixed).toList();
        break;
      case LocationFilter.unfixed:
        filtered = filtered.where((l) => !l.isFixed).toList();
        break;
      case LocationFilter.all:
        break;
    }

    // 검색 적용
    if (search.isNotEmpty) {
      filtered =
          filtered
              .where(
                (l) =>
                    l.name.toLowerCase().contains(search.toLowerCase()) ||
                    (l.address?.toLowerCase().contains(search.toLowerCase()) ??
                        false),
              )
              .toList();
    }

    return filtered;
  });
});

/// 장소 목록 Notifier
class LocationListNotifier extends AsyncNotifier<List<Location>> {
  @override
  Future<List<Location>> build() async {
    return LocationService.getAll();
  }

  /// 목록 새로고침
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => LocationService.getAll());
  }

  /// 장소 추가
  Future<void> addLocation(Location location) async {
    await LocationService.insert(location);
    await refresh();
  }

  /// 장소 업데이트
  Future<void> updateLocation(String id, Location location) async {
    await LocationService.update(id, location);
    await refresh();
  }

  /// 좌표 업데이트
  Future<void> updateCoordinates(String id, double lat, double lng) async {
    await LocationService.updateCoordinates(id, lat: lat, lng: lng);
    await refresh();
  }

  /// 네이버 POI 연결 갱신(또는 해제) — POI 정보로 기본 필드도 동기화한다.
  Future<Location> updateNaverLink(
    String id, {
    required bool linked,
    String? link,
    String? category,
    String? name,
    String? address,
    String? phone,
    double? lat,
    double? lng,
  }) async {
    final updated = await LocationService.updateNaverLink(
      id,
      linked: linked,
      link: link,
      category: category,
      name: name,
      address: address,
      phone: phone,
      lat: lat,
      lng: lng,
    );
    await refresh();
    return updated;
  }

  /// 장소 삭제
  Future<void> deleteLocation(String id) async {
    await LocationService.delete(id);
    await refresh();
  }
}
