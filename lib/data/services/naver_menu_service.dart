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
  static Future<List<NaverMenuItem>> fetchMenus({
    required String locationName,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'naver-place-menu',
        body: {
          'query': locationName,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
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
