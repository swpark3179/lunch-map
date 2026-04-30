# [설계 문서] Naver Maps & Supabase 기반 장소 관리 시스템
## 1. 개요
- 목적: PC에서의 대량 데이터 관리(엑셀)와 모바일 앱에서의 정밀한 위치 등록 기능을 결합한 위치 기반 서비스 구축.
- 주요 특징: * 네이버 지도 기반의 직관적인 UI (중앙 고정 핀 방식).
  - Supabase를 활용한 실시간 데이터 동기화 및 PostGIS 기반 공간 데이터 관리.
  - PC 버전(Flutter Web/Desktop)을 통한 엑셀 대량 업로드 지원.
---
## 2. 기술 스택 (Tech Stack)
- Frontend: Flutter (iOS, Android, Web)
- Backend: Supabase (PostgreSQL + PostGIS)
- Map API: Naver Maps (Mobile SDK)
- Key Packages:
  - flutter_naver_map: 네이버 지도 연동
  - supabase_flutter: 백엔드 통신 및 인증
  - excel: 엑셀 파일 파싱 (PC 업로드용)
  - file_picker: 파일 선택 기능
---
## 3. 데이터베이스 설계 (Supabase)
### Table: locations
| 컬럼명 | 타입 | 설명 |
| id | uuid | 기본키 (PK) |
| name | text | 장소 명칭 (필수) |
| address | text | 주소 정보 (선택) |
| coords | geography(POINT) | PostGIS 위경도 좌표 (결정된 위치) |
| lat | float8 | 위도 (데이터 확인용) |
| lng | float8 | 경도 (데이터 확인용) |
| is_fixed | boolean | "위치 확정 여부 (엑셀 업로드 시 false, 앱 등록 시 true)" |
| created_at | timestamp,생성 일시 |
---
## 4. 핵심 기능 상세 설계
### ① PC 버전: 엑셀 대량 업로드 (Bulk Upload)
1. 사용자 흐름: PC 웹 브라우저에서 .xlsx 파일 선택 → 클라이언트 측 파싱 → Supabase insert 실행.
2. 데이터 처리: * 위치 좌표가 없는 데이터는 is_fixed: false 상태로 우선 등록.
- 기본 위치가 고정된 경우, 해당 좌표를 기본값으로 입력.
### ② 모바일 버전: 좌표 기반 등록 (Map Center UI)
1. UI 구성: Stack 위젯을 사용하여 하단에는 NaverMap을 배치하고, 화면 정중앙에는 고정된 핀 아이콘(Overlay)을 배치.
2. 등록 로직:
- 사용자가 지도를 드래그하여 움직임.
- onCameraIdle (지도 이동 멈춤) 이벤트 발생 시, 지도의 중심 좌표(mapController.nowCameraPosition.target)를 획득.
- '이 위치로 등록' 버튼 클릭 시, 획득한 좌표를 Supabase에 저장/업데이트.
---
## 5. 네이버 지도 연동 설정 (Flutter)
### 기본 설정 단계
1. Naver Cloud Platform: 프로젝트 생성 후 Maps API 신청 및 Client ID 발급.
2. Android 설정: AndroidManifest.xml에 클라이언트 ID 및 권한 추가.
3. iOS 설정: Info.plist에 클라이언트 ID 및 위치 권한 추가.
### 코드 구조 예시
```Dart
// 네이버 지도 초기화 (main.dart)
await NaverMapSdk.instance.initialize(clientId: 'YOUR_CLIENT_ID');

// 위치 선택 화면 UI 구조
Stack(
  children: [
    NaverMap(
      onCameraChange: (reason, animated) {
        // 카메라 이동 중 로직
      },
      onCameraIdle: () {
        // 지도가 멈추면 중심 좌표 저장
        final center = controller.nowCameraPosition.target;
        currentLatLng = center;
      },
    ),
    Center(child: Icon(Icons.location_on, size: 40, color: Colors.red)), // 고정 핀
    Positioned(bottom: 50, child: RegisterButton(onPressed: saveToSupabase)),
  ],
)
```
---
## 6. 개발 로드맵
1. Step 1: Supabase 프로젝트 생성 및 locations 테이블(PostGIS 활성화) 구축.
2. Step 2: 네이버 클라우드 플랫폼에서 Client ID 발급 및 Flutter 연동 환경 설정.
3. Step 3: PC용 엑셀 파싱 및 데이터 일괄 업로드 기능 구현.
4. Step 4: 모바일용 중앙 고정 핀 방식 위치 등록 UI 개발.
5. Step 5: 업로드된 데이터 리스트 조회 및 개별 위치 싱크 맞추기 기능 통합.