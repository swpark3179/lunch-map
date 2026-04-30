-- =====================================================
-- Supabase 마이그레이션: locations 테이블 생성
-- =====================================================

-- 1. PostGIS 및 pg_trgm 확장 활성화
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. locations 테이블 생성
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  coords GEOGRAPHY(POINT, 4326),
  lat FLOAT8,
  lng FLOAT8,
  is_fixed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_locations_is_fixed ON public.locations (is_fixed);
CREATE INDEX IF NOT EXISTS idx_locations_created_at ON public.locations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_locations_name ON public.locations USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_locations_coords ON public.locations USING GIST (coords);

-- 4. RLS(Row Level Security) 설정 (필요에 따라 활성화)
-- ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
-- 
-- CREATE POLICY "Allow all access" ON public.locations
--   FOR ALL USING (true) WITH CHECK (true);

-- 5. 자동 coords 업데이트 트리거
-- lat, lng 값이 변경되면 coords 필드를 자동으로 업데이트
CREATE OR REPLACE FUNCTION update_coords()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.coords := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_coords ON public.locations;

CREATE TRIGGER trigger_update_coords
  BEFORE INSERT OR UPDATE OF lat, lng
  ON public.locations
  FOR EACH ROW
  EXECUTE FUNCTION update_coords();

-- 6. 코멘트 추가
COMMENT ON TABLE public.locations IS '장소 관리 테이블 (Lunch Map)';
COMMENT ON COLUMN public.locations.id IS '기본키 (UUID 자동 생성)';
COMMENT ON COLUMN public.locations.name IS '장소 명칭 (필수)';
COMMENT ON COLUMN public.locations.address IS '주소 정보 (선택)';
COMMENT ON COLUMN public.locations.coords IS 'PostGIS 위경도 좌표 (geography POINT)';
COMMENT ON COLUMN public.locations.lat IS '위도 (데이터 확인용)';
COMMENT ON COLUMN public.locations.lng IS '경도 (데이터 확인용)';
COMMENT ON COLUMN public.locations.is_fixed IS '위치 확정 여부 (엑셀 업로드 시 false, 앱 등록 시 true)';
COMMENT ON COLUMN public.locations.created_at IS '생성 일시';
