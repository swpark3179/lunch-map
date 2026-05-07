#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE_KTS="android/app/build.gradle.kts"
GRADLE_GROOVY="android/app/build.gradle"

[ -f ".env" ] || fail ".env was not created before Android release build"
[ -f "$MANIFEST" ] || fail "AndroidManifest.xml is missing"

grep -q '^SUPABASE_URL=.\+' .env || fail "SUPABASE_URL is missing from .env"
grep -q '^SUPABASE_ANON_KEY=.\+' .env || fail "SUPABASE_ANON_KEY is missing from .env"
grep -q '^NAVER_MAP_CLIENT_ID=.\+' .env || fail "NAVER_MAP_CLIENT_ID is missing from .env"
grep -q '    - .env' pubspec.yaml || fail ".env is not listed as a Flutter asset"

grep -q 'android.permission.INTERNET' "$MANIFEST" ||
  fail "AndroidManifest.xml is missing INTERNET permission"
grep -q 'android.permission.ACCESS_FINE_LOCATION' "$MANIFEST" ||
  fail "AndroidManifest.xml is missing ACCESS_FINE_LOCATION permission"
grep -q 'android.permission.ACCESS_COARSE_LOCATION' "$MANIFEST" ||
  fail "AndroidManifest.xml is missing ACCESS_COARSE_LOCATION permission"
grep -q 'com.naver.maps.map.NCP_KEY_ID' "$MANIFEST" ||
  fail "AndroidManifest.xml is missing Naver Map NCP_KEY_ID metadata"

if [ -f "$GRADLE_KTS" ]; then
  grep -q 'applicationId = "com.shi.lunchmap"' "$GRADLE_KTS" ||
    fail "Kotlin Gradle applicationId is not com.shi.lunchmap"
  grep -q 'namespace = "com.shi.lunchmap"' "$GRADLE_KTS" ||
    fail "Kotlin Gradle namespace is not com.shi.lunchmap"
  grep -Eq 'minSdk\s*=\s*2[3-9]|minSdk\s*=\s*[3-9][0-9]' "$GRADLE_KTS" ||
    fail "Kotlin Gradle minSdk must be at least 23"
elif [ -f "$GRADLE_GROOVY" ]; then
  grep -q 'applicationId "com.shi.lunchmap"' "$GRADLE_GROOVY" ||
    fail "Groovy Gradle applicationId is not com.shi.lunchmap"
  grep -q 'namespace "com.shi.lunchmap"' "$GRADLE_GROOVY" ||
    fail "Groovy Gradle namespace is not com.shi.lunchmap"
  grep -Eq 'minSdkVersion\s+2[3-9]|minSdkVersion\s+[3-9][0-9]' "$GRADLE_GROOVY" ||
    fail "Groovy Gradle minSdk must be at least 23"
else
  fail "Android app Gradle file is missing"
fi

# MainActivity 의 package 선언과 디렉터리 경로가 namespace(com.shi.lunchmap) 와
# 일치하는지 확인한다. 일치하지 않으면 매니페스트의 ".MainActivity" 가
# com.shi.lunchmap.MainActivity 로 해석되는 반면 실제 클래스는 다른 패키지에
# 컴파일되어, 앱 실행 직후 ClassNotFoundException 으로 즉시 강제종료된다.
MAIN_ACTIVITY=""
for candidate in \
  android/app/src/main/kotlin/com/shi/lunchmap/MainActivity.kt \
  android/app/src/main/java/com/shi/lunchmap/MainActivity.java; do
  if [ -f "$candidate" ]; then
    MAIN_ACTIVITY="$candidate"
    break
  fi
done
[ -n "$MAIN_ACTIVITY" ] ||
  fail "MainActivity is missing under com/shi/lunchmap (expected directory does not exist)"
grep -q '^package com\.shi\.lunchmap' "$MAIN_ACTIVITY" ||
  fail "MainActivity package declaration is not 'com.shi.lunchmap' ($MAIN_ACTIVITY)"

# 잘못된 패키지 잔재(com.shi.lunch_map) 가 어디에도 남아있지 않은지 재확인
if grep -RIn 'com\.shi\.lunch_map' android/app/src/main android/app/build.gradle* >/dev/null 2>&1; then
  grep -RIn 'com\.shi\.lunch_map' android/app/src/main android/app/build.gradle* || true
  fail "Stale 'com.shi.lunch_map' references remain in android/ — package unification step did not run cleanly"
fi

echo "Android release configuration checks passed."
