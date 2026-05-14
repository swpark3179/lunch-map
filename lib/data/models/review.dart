/// 메뉴 단위 짧은 후기 모델
class Review {
  final String id;
  final String menuId;
  final String userName;
  final int stars; // 1..5
  final String? comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.menuId,
    required this.userName,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      menuId: json['menu_id'] as String,
      userName: (json['user_name'] as String?) ?? '익명',
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'menu_id': menuId,
        'user_name': userName,
        'stars': stars,
        if (comment != null) 'comment': comment,
      };
}
