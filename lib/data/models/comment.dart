/// 식당 단위 댓글 모델
class LocationComment {
  final String id;
  final String locationId;
  final String userName;
  final String body;
  final DateTime createdAt;

  const LocationComment({
    required this.id,
    required this.locationId,
    required this.userName,
    required this.body,
    required this.createdAt,
  });

  factory LocationComment.fromJson(Map<String, dynamic> json) {
    return LocationComment(
      id: json['id'] as String,
      locationId: json['location_id'] as String,
      userName: (json['user_name'] as String?) ?? '익명',
      body: (json['body'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
