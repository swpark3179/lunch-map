import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// 네이버 Local Search API로부터 파싱한 식당 정보
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
  /// 거제 + [restaurantName] 으로 네이버 장소 검색 후 메뉴 정보 반환.
  static Future<NaverPlaceInfo?> fetchPlaceInfo(String restaurantName) async {
    final clientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';

    if (clientId.isEmpty || clientSecret.isEmpty) return null;

    final uri = Uri.parse(
      'https://openapi.naver.com/v1/search/local.json'
      '?query=${Uri.encodeQueryComponent('거제 $restaurantName')}'
      '&display=5&sort=comment',
    );

    final response = await http.get(
      uri,
      headers: {
        'X-Naver-Client-Id': clientId,
        'X-Naver-Client-Secret': clientSecret,
      },
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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
