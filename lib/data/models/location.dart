/// 장소(식당) 데이터 모델
class Location {
  final String id;
  final String name;
  final String? address;
  final String? category; // kr/jp/cn/wt/as/cf
  final String? phone;
  final double? lat;
  final double? lng;
  final bool isFixed;
  final DateTime createdAt;

  /// 네이버 POI 연결 여부 — 지도뷰에서 자체 caption 을 숨겨
  /// 네이버 기본 라벨과의 중복 표기를 방지한다.
  final bool naverLinked;
  final String? naverLink;
  final String? naverCategory;

  const Location({
    required this.id,
    required this.name,
    this.address,
    this.category,
    this.phone,
    this.lat,
    this.lng,
    this.isFixed = false,
    required this.createdAt,
    this.naverLinked = false,
    this.naverLink,
    this.naverCategory,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      category: json['category'] as String?,
      phone: json['phone'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isFixed: json['is_fixed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      naverLinked: json['naver_linked'] as bool? ?? false,
      naverLink: json['naver_link'] as String?,
      naverCategory: json['naver_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (address != null) 'address': address,
      if (category != null) 'category': category,
      if (phone != null) 'phone': phone,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'is_fixed': isFixed,
      'naver_linked': naverLinked,
      if (naverLink != null) 'naver_link': naverLink,
      if (naverCategory != null) 'naver_category': naverCategory,
      // coords(geography) 는 DB 트리거가 lat/lng 로부터 계산하므로 보내지 않는다.
    };
  }

  Location copyWith({
    String? id,
    String? name,
    String? address,
    String? category,
    String? phone,
    double? lat,
    double? lng,
    bool? isFixed,
    DateTime? createdAt,
    bool? naverLinked,
    String? naverLink,
    String? naverCategory,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isFixed: isFixed ?? this.isFixed,
      createdAt: createdAt ?? this.createdAt,
      naverLinked: naverLinked ?? this.naverLinked,
      naverLink: naverLink ?? this.naverLink,
      naverCategory: naverCategory ?? this.naverCategory,
    );
  }

  bool get hasCoordinates => lat != null && lng != null;

  @override
  String toString() =>
      'Location(id: $id, name: $name, fixed: $isFixed, naver: $naverLinked)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
