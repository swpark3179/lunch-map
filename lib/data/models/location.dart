/// 장소 데이터 모델
class Location {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final bool isFixed;
  final DateTime createdAt;

  const Location({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.isFixed = false,
    required this.createdAt,
  });

  /// Supabase JSON → Location 객체 변환
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isFixed: json['is_fixed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Location 객체 → Supabase JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'is_fixed': isFixed,
      // coords(geography)는 lat/lng가 있을 때 DB 트리거 또는 서비스 레이어에서 처리
      if (lat != null && lng != null)
        'coords': 'POINT($lng $lat)',
    };
  }

  /// copyWith 패턴
  Location copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    bool? isFixed,
    DateTime? createdAt,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isFixed: isFixed ?? this.isFixed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 좌표 존재 여부
  bool get hasCoordinates => lat != null && lng != null;

  @override
  String toString() => 'Location(id: $id, name: $name, fixed: $isFixed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
