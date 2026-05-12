/// 지도 관련 공통 상수
library;

/// 지도 기본 시작 위도 (장소목록 지도뷰 / 지도등록 화면 공통)
const double kDefaultLat = 34.892874;

/// 지도 기본 시작 경도
const double kDefaultLng = 128.604519;

/// 기본 시작 줌 레벨
const double kDefaultZoom = 17;

/// 삼성중공업 후문 영역 중심 좌표
const double kSamsungRearGateLat = 34.892958;
const double kSamsungRearGateLng = 128.604391;

/// 영역 반경 (m) — 경로 두께와 자연스럽게 이어지도록 기존 25m의 1/4 크기
const double kSamsungRearGateRadiusMeters = 6.25;

/// 기본 경로 영역 좌표 (위도, 경도 순서). 순서대로 이어진다.
const List<List<double>> kDefaultPathwayCoords = <List<double>>[
  <double>[34.895393, 128.600724],
  <double>[34.895109, 128.600963],
  <double>[34.895230, 128.601190],
  <double>[34.894855, 128.601790],
  <double>[34.892936, 128.604444],
];
