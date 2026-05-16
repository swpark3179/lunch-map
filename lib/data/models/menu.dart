/// 식당 메뉴 데이터 모델
class MenuItem {
  final String id;
  final String locationId;
  final String name;
  final int price;
  final int sortOrder;
  final DateTime createdAt;

  /// 메뉴 단위 별점/후기 모델은 제거되었지만 예산 추천 로직과의
  /// 호환을 위해 필드는 남겨두고 항상 0 으로 채운다.
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
    return MenuItem(
      id: json['id'] as String,
      locationId: json['location_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
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
