# lunch-map

## 개발 환경

### 사전 요구사항

- Flutter 3.29+ / Dart 3.7+
- Supabase 프로젝트 (PostGIS 활성화)
- Naver Cloud Platform Client ID (Maps API)

### 프로젝트 설정

1. **의존성 설치**
```bash
flutter pub get
```

2. **환경변수 설정**
`.env` 파일을 편집하여 실제 키를 입력하세요:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
NAVER_MAP_CLIENT_ID=your-client-id
```

3. **Supabase 데이터베이스 설정**
`supabase/migrations/001_create_locations.sql` 파일의 SQL을 Supabase SQL Editor에서 실행하세요.

4. **Android 설정** (`android/app/src/main/AndroidManifest.xml`에 추가)
```xml
<meta-data
  android:name="com.naver.maps.map.CLIENT_ID"
  android:value="YOUR_CLIENT_ID" />
```

5. **iOS 설정** (`ios/Runner/Info.plist`에 추가)
```xml
<key>NMFClientId</key>
<string>YOUR_CLIENT_ID</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>현재 위치를 표시하기 위해 위치 권한이 필요합니다.</string>
```

### 실행

```bash
# 모바일 (Android/iOS)
flutter run

# 웹
flutter run -d chrome
```

## 프로젝트 구조

```
lib/
├── main.dart              # 앱 진입점
├── app.dart               # MaterialApp 설정
├── core/
│   ├── theme/
│   │   └── app_theme.dart # 테마 시스템
│   ├── router/
│   │   └── app_router.dart # GoRouter 라우팅
│   └── shell/
│       └── app_shell.dart  # 공통 셸 (바텀 네비)
├── data/
│   ├── models/
│   │   └── location.dart   # Location 데이터 모델
│   └── services/
│       └── location_service.dart # Supabase CRUD
├── providers/
│   └── location_provider.dart   # Riverpod 상태관리
└── features/
    ├── home/
    │   └── home_screen.dart        # 홈 대시보드
    ├── location_list/
    │   └── location_list_screen.dart # 장소 목록
    ├── location_detail/
    │   └── location_detail_screen.dart # 장소 상세
    ├── map_picker/
    │   ├── map_picker_screen.dart    # 지도 위치 선택
    │   ├── map_picker_mobile.dart    # 모바일 네이버 지도
    │   └── map_picker_web.dart      # 웹 플레이스홀더
    └── excel_upload/
        └── excel_upload_screen.dart  # 엑셀 업로드
```

## 주요 기능

1. **홈 대시보드**: 통계 카드, 빠른 액션 링크
2. **장소 목록**: 필터(전체/확정/미확정), 검색, CRUD
3. **지도 위치 등록**: 네이버 지도 중앙 고정 핀 방식 (모바일)
4. **엑셀 업로드**: .xlsx 파일 파싱, 컬럼 매핑, 미리보기, 일괄 등록 (PC)
