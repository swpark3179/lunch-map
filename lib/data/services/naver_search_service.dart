import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

/// 네이버 Local Search API로부터 파싱한 식당 정보
class NaverPlaceInfo {
  final String title;
  final String category;
  final String description;
  final String telephone;
  final String roadAddress;
  final String link;

  /// 네이버 API mapx/mapy(WGS84 × 10⁷)를 변환한 좌표
  final double? placeLat;
  final double? placeLng;

  const NaverPlaceInfo({
    required this.title,
    required this.category,
    required this.description,
    required this.telephone,
    required this.roadAddress,
    required this.link,
    this.placeLat,
    this.placeLng,
  });

  factory NaverPlaceInfo.fromJson(Map<String, dynamic> json) {
    final mapx = int.tryParse(json['mapx'] as String? ?? '');
    final mapy = int.tryParse(json['mapy'] as String? ?? '');
    return NaverPlaceInfo(
      title: _stripHtml(json['title'] as String? ?? ''),
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
      link: json['link'] as String? ?? '',
      placeLat: mapy != null ? mapy / 1e7 : null,
      placeLng: mapx != null ? mapx / 1e7 : null,
    );
  }

  bool get hasDescription => description.isNotEmpty;
  bool get hasLink => link.isNotEmpty;

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '');
}

class NaverSearchService {
  static final _client = Supabase.instance.client;

  /// 거제 + [restaurantName] 으로 네이버 장소 검색 후 정보 반환.
  ///
  /// [lat]/[lng]가 제공되면 좌표 기반으로 가장 가까운 결과를 선택한다.
  /// 좌표가 없거나 결과에 좌표 정보가 없으면 이름 유사도로 폴백한다.
  static Future<NaverPlaceInfo?> fetchPlaceInfo(
    String restaurantName, {
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'naver-search',
      body: {'query': '거제 $restaurantName'},
    );

    final data = response.data;
    if (data == null) return null;

    final items = data['items'] as List?;
    if (items == null || items.isEmpty) return null;

    final castItems = items.cast<Map<String, dynamic>>();

    // 좌표가 있으면 가장 가까운 결과 선택
    if (lat != null && lng != null) {
      final byCoord = _bestByCoordinates(castItems, lat, lng);
      if (byCoord != null) return NaverPlaceInfo.fromJson(byCoord);
    }

    // 이름 유사도 기반 폴백
    return NaverPlaceInfo.fromJson(_bestByName(castItems, restaurantName));
  }

  /// 저장된 좌표에서 가장 가까운 항목 반환.
  /// 항목에 좌표 정보가 없으면 null 반환.
  static Map<String, dynamic>? _bestByCoordinates(
    List<Map<String, dynamic>> items,
    double lat,
    double lng,
  ) {
    Map<String, dynamic>? best;
    double bestDist = double.infinity;

    for (final item in items) {
      final mapx = int.tryParse(item['mapx'] as String? ?? '');
      final mapy = int.tryParse(item['mapy'] as String? ?? '');
      if (mapx == null || mapy == null) continue;

      final itemLat = mapy / 1e7;
      final itemLng = mapx / 1e7;
      final dist = _squaredDistance(lat, lng, itemLat, itemLng);
      if (dist < bestDist) {
        bestDist = dist;
        best = item;
      }
    }

    return best;
  }

  /// 이름 유사도 기반으로 가장 비슷한 항목 반환 (없으면 첫 번째).
  static Map<String, dynamic> _bestByName(
    List<Map<String, dynamic>> items,
    String restaurantName,
  ) {
    final nameLower = restaurantName.toLowerCase();
    for (final item in items) {
      final title = NaverPlaceInfo._stripHtml(
        (item['title'] as String? ?? ''),
      ).toLowerCase();
      if (title.contains(nameLower) || nameLower.contains(title)) {
        return item;
      }
    }
    return items.first;
  }

  /// 키워드로 네이버 장소를 검색해 전체 결과 목록 반환 (식당 추가용).
  /// "거제 " 접두어를 자동으로 붙여 지역 검색을 수행한다.
  static Future<List<NaverPlaceInfo>> searchAll(String query) async {
    final response = await _client.functions.invoke(
      'naver-search',
      body: {'query': '거제 $query', 'display': 10},
    );

    final data = response.data;
    if (data == null) return [];

    final items = data['items'] as List?;
    if (items == null || items.isEmpty) return [];

    return items
        .cast<Map<String, dynamic>>()
        .map(NaverPlaceInfo.fromJson)
        .toList();
  }

  /// 위경도 차이의 제곱합 (상대적 거리 비교용).
  static double _squaredDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dlat = lat1 - lat2;
    final dlng = (lng1 - lng2) * math.cos(lat1 * math.pi / 180);
    return dlat * dlat + dlng * dlng;
  }
}
