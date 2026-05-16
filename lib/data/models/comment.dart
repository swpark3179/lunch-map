/// 식당 단위 댓글 모델
class LocationComment {
  final String id;
  final String locationId;
  final String userName;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocationComment({
    required this.id,
    required this.locationId,
    required this.userName,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEdited => updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)));

  factory LocationComment.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final updatedRaw = json['updated_at'] as String?;
    return LocationComment(
      id: json['id'] as String,
      locationId: json['location_id'] as String,
      userName: (json['user_name'] as String?) ?? '익명',
      body: (json['body'] as String?) ?? '',
      createdAt: createdAt,
      updatedAt: updatedRaw != null ? DateTime.parse(updatedRaw) : createdAt,
    );
  }
}
