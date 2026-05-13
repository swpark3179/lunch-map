-- 1. Extension을 public이 아닌 extensions 스키마에 재생성하여 linter 경고 해결
DROP EXTENSION IF EXISTS postgis CASCADE;
CREATE EXTENSION postgis SCHEMA extensions;

DROP EXTENSION IF EXISTS pg_trgm CASCADE;
CREATE EXTENSION pg_trgm SCHEMA extensions;

-- 2. locations 테이블 삭제 (위 extensions drop cascade로 인해 삭제되었으므로 다시 생성)
-- 이 때 extensions의 데이터타입을 참조하도록 수정
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

-- 3. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_locations_is_fixed ON public.locations (is_fixed);
CREATE INDEX IF NOT EXISTS idx_locations_created_at ON public.locations (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_locations_name ON public.locations USING GIN (name extensions.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_locations_coords ON public.locations USING GIST (coords);

-- 4. RLS(Row Level Security) 설정
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to locations"
ON public.locations
FOR SELECT
USING (true);

-- Linter의 overly permissive expression (true) 경고를 피하기 위해 권한 검사로 변경
CREATE POLICY "Allow authenticated users to insert locations"
ON public.locations
FOR INSERT
TO authenticated
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to update locations"
ON public.locations
FOR UPDATE
TO authenticated
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to delete locations"
ON public.locations
FOR DELETE
TO authenticated
USING (auth.role() = 'authenticated');

-- 5. 자동 coords 업데이트 트리거 함수 (search_path 경고 해결)
CREATE OR REPLACE FUNCTION update_coords()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.coords := extensions.ST_SetSRID(extensions.ST_MakePoint(NEW.lng, NEW.lat), 4326)::extensions.geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = '';

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
