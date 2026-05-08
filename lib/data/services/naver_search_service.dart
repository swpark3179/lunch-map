import 'package:supabase_flutter/supabase_flutter.dart';

/// 네이버 Local Search API로부터 파싱한 식당 메뉴 정보
class NaverPlaceInfo {
  final String title;
  final String category;
  final String description;
  final String telephone;
  final String roadAddress;

  const NaverPlaceInfo({
    required this.title,
    required this.category,
    required this.description,
    required this.telephone,
    required this.roadAddress,
  });

  factory NaverPlaceInfo.fromJson(Map<String, dynamic> json) {
    return NaverPlaceInfo(
      title: _stripHtml(json['title'] as String? ?? ''),
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
    );
  }

  bool get hasDescription => description.isNotEmpty;

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '');
}

class NaverSearchService {
  static final _client = Supabase.instance.client;

  /// 거제 + [restaurantName] 으로 네이버 장소 검색 후 메뉴 정보 반환.
  /// 검색 결과 중 식당 이름이 가장 유사한 항목을 선택한다.
  static Future<NaverPlaceInfo?> fetchPlaceInfo(String restaurantName) async {
    final response = await _client.functions.invoke(
      'naver-search',
      body: {'query': '거제 $restaurantName'},
    );

    final data = response.data;
    if (data == null) return null;

    final items = data['items'] as List?;
    if (items == null || items.isEmpty) return null;

    // 이름이 가장 잘 매칭되는 항목 선택
    final nameLower = restaurantName.toLowerCase();
    Map<String, dynamic>? best;
    for (final item in items) {
      final title = NaverPlaceInfo._stripHtml(
        (item['title'] as String? ?? ''),
      ).toLowerCase();
      if (title.contains(nameLower) || nameLower.contains(title)) {
        best = item as Map<String, dynamic>;
        break;
      }
    }
    best ??= items.first as Map<String, dynamic>;

    return NaverPlaceInfo.fromJson(best);
  }
}
