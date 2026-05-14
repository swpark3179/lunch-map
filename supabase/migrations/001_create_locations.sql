-- ============================================================
-- 001 · locations 테이블 + 필수 익스텐션
-- ------------------------------------------------------------
-- 이 마이그레이션은 반복 실행 가능하도록 작성되어 있습니다.
-- 이전 버전은 `DROP EXTENSION ... CASCADE` 로 인해 의존 테이블이
-- 함께 삭제되어 데이터 손실이 발생하는 문제가 있었습니다.
-- 이번 버전은 다음 원칙을 따릅니다.
--   1) Extension 은 extensions 스키마에 IF NOT EXISTS 로만 생성한다.
--   2) 테이블/인덱스/정책/트리거는 모두 IF NOT EXISTS 또는 OR REPLACE
--      로 안전하게 적용한다.
--   3) 정책은 DROP POLICY IF EXISTS 후 CREATE POLICY 로 갱신한다.
--      (CREATE POLICY 자체는 IF NOT EXISTS 를 지원하지 않음)
-- ============================================================

-- 1. Extensions (extensions 스키마, 멱등)
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- 2. locations 테이블
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  coords extensions.GEOGRAPHY(POINT, 4326),
  lat FLOAT8,
  lng FLOAT8,
  is_fixed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 인덱스
CREATE INDEX IF NOT EXISTS idx_locations_is_fixed
  ON public.locations (is_fixed);
CREATE INDEX IF NOT EXISTS idx_locations_created_at
  ON public.locations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_locations_name
  ON public.locations USING GIN (name extensions.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_locations_coords
  ON public.locations USING GIST (coords);

-- 4. RLS
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to locations"  ON public.locations;
DROP POLICY IF EXISTS "Allow anon to insert locations"         ON public.locations;
DROP POLICY IF EXISTS "Allow anon to update locations"         ON public.locations;
DROP POLICY IF EXISTS "Allow anon to delete locations"         ON public.locations;
DROP POLICY IF EXISTS "Allow authenticated users to insert locations" ON public.locations;
DROP POLICY IF EXISTS "Allow authenticated users to update locations" ON public.locations;
DROP POLICY IF EXISTS "Allow authenticated users to delete locations" ON public.locations;

-- 익명 키로도 동작하도록 anon/authenticated 둘 다 허용한다.
-- (앱이 사용자 로그인을 도입하면 다시 제한할 것)
CREATE POLICY "Allow public read access to locations"
  ON public.locations FOR SELECT
  USING (true);

CREATE POLICY "Allow anon to insert locations"
  ON public.locations FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow anon to update locations"
  ON public.locations FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow anon to delete locations"
  ON public.locations FOR DELETE
  TO anon, authenticated
  USING (true);

-- 5. 좌표 자동 계산 트리거
CREATE OR REPLACE FUNCTION public.update_coords()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.coords := extensions.ST_SetSRID(
      extensions.ST_MakePoint(NEW.lng, NEW.lat), 4326
    )::extensions.geography;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_coords ON public.locations;
CREATE TRIGGER trigger_update_coords
  BEFORE INSERT OR UPDATE OF lat, lng
  ON public.locations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_coords();

-- 6. 코멘트
COMMENT ON TABLE  public.locations           IS '장소 관리 테이블 (Lunch Map)';
COMMENT ON COLUMN public.locations.id        IS '기본키 (UUID 자동 생성)';
COMMENT ON COLUMN public.locations.name      IS '장소 명칭 (필수)';
COMMENT ON COLUMN public.locations.address   IS '주소 (선택)';
COMMENT ON COLUMN public.locations.coords    IS 'PostGIS 위경도 좌표 (geography POINT)';
COMMENT ON COLUMN public.locations.lat       IS '위도';
COMMENT ON COLUMN public.locations.lng       IS '경도';
COMMENT ON COLUMN public.locations.is_fixed  IS '위치 확정 여부';
COMMENT ON COLUMN public.locations.created_at IS '생성 일시';
