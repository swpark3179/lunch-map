import '../../data/models/location.dart';
import '../../data/models/menu.dart';

/// 예산 추천 결과 — 식당 단위 메뉴 조합
class BudgetCombo {
  final Location restaurant;
  final List<MenuItem> menus;
  final int total;
  final double avgRating;
  final double score;

  const BudgetCombo({
    required this.restaurant,
    required this.menus,
    required this.total,
    required this.avgRating,
    required this.score,
  });
}

/// 단품 가성비 추천
class ValuePick {
  final Location restaurant;
  final MenuItem menu;
  final double score;
  final double value; // 가성비 점수 (별점/만원)

  const ValuePick({
    required this.restaurant,
    required this.menu,
    required this.score,
    required this.value,
  });
}

/// 식당별 최적 메뉴 조합 (1~3 개). 디자인의 budget-logic.jsx 와 동일한 방식.
List<BudgetCombo> recommendCombos({
  required Map<String, Location> restaurantsById,
  required Map<String, List<MenuItem>> menusByRestaurant,
  required int budget,
}) {
  final results = <BudgetCombo>[];

  menusByRestaurant.forEach((rid, menus) {
    final r = restaurantsById[rid];
    if (r == null) return;
    final subsets = <List<MenuItem>>[];

    // 1개
    for (final m in menus) {
      if (m.price <= budget) subsets.add([m]);
    }
    // 2개
    for (var i = 0; i < menus.length; i++) {
      for (var j = i + 1; j < menus.length; j++) {
        final total = menus[i].price + menus[j].price;
        if (total <= budget) subsets.add([menus[i], menus[j]]);
      }
    }
    // 3개
    for (var i = 0; i < menus.length; i++) {
      for (var j = i + 1; j < menus.length; j++) {
        for (var k = j + 1; k < menus.length; k++) {
          final total = menus[i].price + menus[j].price + menus[k].price;
          if (total <= budget) subsets.add([menus[i], menus[j], menus[k]]);
        }
      }
    }

    for (final s in subsets) {
      final total = s.fold<int>(0, (a, b) => a + b.price);
      final avgRating = s.isEmpty
          ? 0.0
          : s.map((e) => e.avgStars).reduce((a, b) => a + b) / s.length;
      final fill = total / budget;
      // 95% 채움까지는 보너스, 그 이상은 감점
      final fillScore = fill > 0.95 ? 0.95 - (fill - 0.95) * 2 : fill;
      final score = fillScore * 0.6 + (avgRating / 5) * 0.4;
      results.add(BudgetCombo(
        restaurant: r,
        menus: s,
        total: total,
        avgRating: avgRating,
        score: score,
      ));
    }
  });

  // 식당별로 가장 좋은 조합만 유지
  final byR = <String, BudgetCombo>{};
  for (final c in results) {
    final prev = byR[c.restaurant.id];
    if (prev == null || c.score > prev.score) byR[c.restaurant.id] = c;
  }
  final list = byR.values.toList()..sort((a, b) => b.score.compareTo(a.score));
  return list;
}

/// 식당 구분 없이 단품 메뉴를 가성비/별점 기준으로 정렬한 추천 목록.
List<ValuePick> recommendValueMenus({
  required Map<String, Location> restaurantsById,
  required List<MenuItem> menus,
  required int budget,
}) {
  final items = <ValuePick>[];
  for (final m in menus) {
    final r = restaurantsById[m.locationId];
    if (r == null) continue;
    if (m.price <= 0 || m.price > budget) continue;
    final ratingScore = (m.avgStars / 5) * 0.5;
    final cheapScore = (1 - m.price / budget) * 0.2;
    final reviewBonus = m.reviewCount > 0 ? 0.1 : 0.0;
    final score = ratingScore + cheapScore + reviewBonus + 0.2;
    final value = m.price == 0 ? 0.0 : m.avgStars / (m.price / 10000);
    items.add(ValuePick(restaurant: r, menu: m, score: score, value: value));
  }
  items.sort((a, b) => b.score.compareTo(a.score));
  return items;
}
