import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu.dart';
import '../models/review.dart';

class MenuService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'menus';

  /// 특정 식당의 메뉴 목록 (menu_stats 뷰 join 으로 별점/리뷰 수 포함)
  static Future<List<MenuItem>> getByLocation(String locationId) async {
    final rows = await _client
        .from(_table)
        .select('*, menu_stats(avg_stars, review_count)')
        .eq('location_id', locationId)
        .order('sort_order')
        .order('created_at');
    return (rows as List).map((j) => MenuItem.fromJson(j)).toList();
  }

  /// 모든 메뉴(예산 추천용)
  static Future<List<MenuItem>> getAllWithStats() async {
    final rows = await _client
        .from(_table)
        .select('*, menu_stats(avg_stars, review_count)')
        .order('price');
    return (rows as List).map((j) => MenuItem.fromJson(j)).toList();
  }

  static Future<MenuItem> insert({
    required String locationId,
    required String name,
    required int price,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'location_id': locationId,
          'name': name,
          'price': price,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return MenuItem.fromJson(row);
  }

  static Future<MenuItem> update(
    String id, {
    String? name,
    int? price,
    int? sortOrder,
  }) async {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (price != null) patch['price'] = price;
    if (sortOrder != null) patch['sort_order'] = sortOrder;
    final row =
        await _client.from(_table).update(patch).eq('id', id).select().single();
    return MenuItem.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

class ReviewService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'reviews';

  static Future<List<Review>> getByMenu(String menuId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('menu_id', menuId)
        .order('created_at', ascending: false);
    return (rows as List).map((j) => Review.fromJson(j)).toList();
  }

  static Future<Review> add({
    required String menuId,
    required String userName,
    required int stars,
    String? comment,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'menu_id': menuId,
          'user_name': userName.isEmpty ? '익명' : userName,
          'stars': stars.clamp(1, 5),
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        })
        .select()
        .single();
    return Review.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
