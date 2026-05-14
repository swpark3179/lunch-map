/// 식당 메뉴 데이터 모델
class MenuItem {
  final String id;
  final String locationId;
  final String name;
  final int price;
  final int sortOrder;
  final DateTime createdAt;

  /// 집계 — menu_stats 뷰 join 으로 채워진다 (없으면 0).
  final double avgStars;
  final int reviewCount;

  const MenuItem({
    required this.id,
    required this.locationId,
    required this.name,
    required this.price,
    this.sortOrder = 0,
    required this.createdAt,
    this.avgStars = 0,
    this.reviewCount = 0,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final stats = json['menu_stats'];
    double avg = 0;
    int count = 0;
    if (stats is Map) {
      avg = (stats['avg_stars'] as num?)?.toDouble() ?? 0;
      count = (stats['review_count'] as num?)?.toInt() ?? 0;
    } else if (stats is List && stats.isNotEmpty) {
      final s = stats.first as Map;
      avg = (s['avg_stars'] as num?)?.toDouble() ?? 0;
      count = (s['review_count'] as num?)?.toInt() ?? 0;
    }
    return MenuItem(
      id: json['id'] as String,
      locationId: json['location_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      avgStars: avg,
      reviewCount: count,
    );
  }

  Map<String, dynamic> toJson() => {
        'location_id': locationId,
        'name': name,
        'price': price,
        'sort_order': sortOrder,
      };

  MenuItem copyWith({
    String? name,
    int? price,
    int? sortOrder,
    double? avgStars,
    int? reviewCount,
  }) =>
      MenuItem(
        id: id,
        locationId: locationId,
        name: name ?? this.name,
        price: price ?? this.price,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        avgStars: avgStars ?? this.avgStars,
        reviewCount: reviewCount ?? this.reviewCount,
      );
}
