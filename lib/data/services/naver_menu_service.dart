import 'package:supabase_flutter/supabase_flutter.dart';

class NaverMenuItem {
  final String name;
  final int? price;
  final String category;

  const NaverMenuItem({
    required this.name,
    this.price,
    required this.category,
  });

  factory NaverMenuItem.fromJson(Map<String, dynamic> json) {
    return NaverMenuItem(
      name: json['name'] as String? ?? '',
      price: json['price'] as int?,
      category: json['category'] as String? ?? '',
    );
  }
}

class NaverMenuService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 식당 이름으로 네이버에서 메뉴 목록을 가져온다.
  ///
  /// [naverLink] 가 주어지면 Local Search 단계를 건너뛰고 해당 POI 의
  /// placeId 로 직접 메뉴를 조회한다. 이미 POI 가 연결된 식당의 경우
  /// 이름 재검색으로 엉뚱한 가게가 매칭되는 문제를 피한다.
  static Future<List<NaverMenuItem>> fetchMenus({
    required String locationName,
    double? lat,
    double? lng,
    String? naverLink,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'naver-place-menu',
        body: {
          'query': locationName,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (naverLink != null && naverLink.isNotEmpty) 'naverLink': naverLink,
        },
      );

      final data = response.data;
      if (data == null) return const [];

      final menuList = data['menus'] as List<dynamic>? ?? [];
      return menuList
          .whereType<Map<String, dynamic>>()
          .map(NaverMenuItem.fromJson)
          .where((m) => m.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
