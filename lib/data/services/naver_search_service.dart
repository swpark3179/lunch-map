import 'package:supabase_flutter/supabase_flutter.dart';

class NaverMenuItem {
  final String name;
  final String price;
  final String description;
  final String imageUrl;

  const NaverMenuItem({
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  factory NaverMenuItem.fromJson(Map<String, dynamic> json) {
    return NaverMenuItem(
      name: json['name'] as String? ?? '',
      price: json['price'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  bool get hasPrice => price.isNotEmpty;
}

/// 네이버 Local Search API로부터 파싱한 식당 정보
class NaverPlaceInfo {
  final String title;
  final String category;
  final String description;
  final String telephone;
  final String roadAddress;
  final String link;
  final String? placeId;
  final List<NaverMenuItem> menus;

  const NaverPlaceInfo({
    required this.title,
    required this.category,
    required this.description,
    required this.telephone,
    required this.roadAddress,
    this.link = '',
    this.placeId,
    this.menus = const [],
  });

  factory NaverPlaceInfo.fromJson(Map<String, dynamic> json) {
    final rawMenus = json['menus'] as List<dynamic>? ?? [];
    return NaverPlaceInfo(
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
      link: json['link'] as String? ?? '',
      placeId: json['placeId'] as String?,
      menus: rawMenus
          .whereType<Map<String, dynamic>>()
          .map(NaverMenuItem.fromJson)
          .where((m) => m.name.isNotEmpty)
          .toList(),
    );
  }

  bool get hasMenus => menus.isNotEmpty;
  bool get hasDescription => description.isNotEmpty;
}

class NaverSearchService {
  static final _client = Supabase.instance.client;

  /// 거제 + [restaurantName] 으로 네이버 장소 검색 후 정보 반환.
  static Future<NaverPlaceInfo?> fetchPlaceInfo(String restaurantName) async {
    final response = await _client.functions.invoke(
      'naver-search',
      body: {'query': '거제 $restaurantName'},
    );

    final data = response.data;
    if (data == null) return null;
    if (data is! Map<String, dynamic>) return null;
    if (data.containsKey('error')) return null;

    // 새 응답 형식: 단일 객체 (title, menus 등)
    if (data.containsKey('title')) {
      return NaverPlaceInfo.fromJson(data);
    }

    // 이전 형식 호환: { items: [...] }
    final items = data['items'] as List?;
    if (items == null || items.isEmpty) return null;
    return NaverPlaceInfo.fromJson(items.first as Map<String, dynamic>);
  }
}
