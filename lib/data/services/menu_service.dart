import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';
import '../models/menu.dart';

class MenuService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'menus';

  static Future<List<MenuItem>> getByLocation(String locationId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('location_id', locationId)
        .order('sort_order')
        .order('created_at');
    return (rows as List).map((j) => MenuItem.fromJson(j)).toList();
  }

  /// 예산 추천용 — 모든 메뉴.
  static Future<List<MenuItem>> getAllWithStats() async {
    final rows = await _client.from(_table).select().order('price');
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

/// 식당 단위 댓글 서비스
class CommentService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'location_comments';

  static Future<List<LocationComment>> getByLocation(String locationId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('location_id', locationId)
        .order('created_at', ascending: false);
    return (rows as List).map((j) => LocationComment.fromJson(j)).toList();
  }

  static Future<LocationComment> add({
    required String locationId,
    required String userName,
    required String body,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'location_id': locationId,
          'user_name': userName.trim().isEmpty ? '익명' : userName.trim(),
          'body': body,
        })
        .select()
        .single();
    return LocationComment.fromJson(row);
  }

  static Future<LocationComment> update(
    String id, {
    String? userName,
    String? body,
  }) async {
    final patch = <String, dynamic>{};
    if (userName != null) {
      patch['user_name'] = userName.trim().isEmpty ? '익명' : userName.trim();
    }
    if (body != null) patch['body'] = body;
    final row = await _client
        .from(_table)
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return LocationComment.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
