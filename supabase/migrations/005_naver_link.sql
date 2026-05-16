-- ============================================================
-- 005 · locations 에 네이버 POI 연결 정보 추가
-- ------------------------------------------------------------
-- 식당 등록 시 네이버 지도 POI 또는 검색 결과와 연결되면
-- 해당 사실과 부가 정보(카테고리, 외부 링크)를 저장한다.
--
-- 목적
--   1) 장소 목록 지도뷰에서 네이버 기본 라벨과 우리 caption 이
--      중복되어 보이는 문제를 해결할 근거 데이터로 사용한다.
--   2) 상세/등록 화면에서 POI 정보를 표시하고, 메뉴 자동 가져오기를
--      활성화하는 트리거로 사용한다.
-- ============================================================

ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS naver_linked    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS naver_link      TEXT,
  ADD COLUMN IF NOT EXISTS naver_category  TEXT;

COMMENT ON COLUMN public.locations.naver_linked   IS '네이버 POI 와 연결되었는지 여부';
COMMENT ON COLUMN public.locations.naver_link     IS '네이버 장소 페이지 URL (연결 시)';
COMMENT ON COLUMN public.locations.naver_category IS '네이버에서 가져온 카테고리 문자열';

CREATE INDEX IF NOT EXISTS idx_locations_naver_linked
  ON public.locations (naver_linked);
