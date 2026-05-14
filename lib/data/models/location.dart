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
    );
  }

  bool get hasCoordinates => lat != null && lng != null;

  @override
  String toString() => 'Location(id: $id, name: $name, fixed: $isFixed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
