-- ============================================================
-- 002 · 메뉴 · 후기 · 카테고리 / 전화번호 (OPUS-X redesign)
-- ------------------------------------------------------------
-- 마이그레이션은 멱등하게 작성되어 있습니다.
-- locations 에 category / phone 컬럼을 추가하고,
-- menus / reviews 테이블을 신설합니다.
-- ============================================================

-- 1. locations 컬럼 확장
ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS phone    TEXT;

CREATE INDEX IF NOT EXISTS idx_locations_category
  ON public.locations (category);

COMMENT ON COLUMN public.locations.category IS '카테고리 키 (kr/jp/cn/wt/as/cf)';
COMMENT ON COLUMN public.locations.phone    IS '전화번호 (자유 포맷)';

-- 2. menus 테이블
CREATE TABLE IF NOT EXISTS public.menus (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id  UUID NOT NULL REFERENCES public.locations(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  price        INTEGER NOT NULL DEFAULT 0,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_menus_location_id
  ON public.menus (location_id);
CREATE INDEX IF NOT EXISTS idx_menus_price
  ON public.menus (price);

COMMENT ON TABLE  public.menus            IS '식당 메뉴';
COMMENT ON COLUMN public.menus.location_id IS '소속 식당 ID (FK)';
COMMENT ON COLUMN public.menus.price       IS '가격 (KRW, 정수)';

ALTER TABLE public.menus ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menus_select" ON public.menus;
DROP POLICY IF EXISTS "menus_insert" ON public.menus;
DROP POLICY IF EXISTS "menus_update" ON public.menus;
DROP POLICY IF EXISTS "menus_delete" ON public.menus;

CREATE POLICY "menus_select" ON public.menus FOR SELECT USING (true);
CREATE POLICY "menus_insert" ON public.menus FOR INSERT
  TO anon, authenticated WITH CHECK (true);
CREATE POLICY "menus_update" ON public.menus FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "menus_delete" ON public.menus FOR DELETE
  TO anon, authenticated USING (true);

-- 3. reviews 테이블 (메뉴 단위 후기)
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id     UUID NOT NULL REFERENCES public.menus(id) ON DELETE CASCADE,
  user_name   TEXT NOT NULL DEFAULT '익명',
  stars       SMALLINT NOT NULL DEFAULT 5
              CHECK (stars BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_menu_id
  ON public.reviews (menu_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at
  ON public.reviews (created_at DESC);

COMMENT ON TABLE  public.reviews          IS '메뉴 단위 짧은 후기';
COMMENT ON COLUMN public.reviews.menu_id  IS '대상 메뉴 ID (FK)';
COMMENT ON COLUMN public.reviews.stars    IS '별점 (1~5)';

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews_select" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert" ON public.reviews;
DROP POLICY IF EXISTS "reviews_update" ON public.reviews;
DROP POLICY IF EXISTS "reviews_delete" ON public.reviews;

CREATE POLICY "reviews_select" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert" ON public.reviews FOR INSERT
  TO anon, authenticated WITH CHECK (true);
CREATE POLICY "reviews_update" ON public.reviews FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "reviews_delete" ON public.reviews FOR DELETE
  TO anon, authenticated USING (true);

-- 4. 메뉴 평균 별점 / 후기 수 뷰
CREATE OR REPLACE VIEW public.menu_stats AS
  SELECT
    m.id            AS menu_id,
    m.location_id   AS location_id,
    COALESCE(AVG(r.stars)::FLOAT8, 0)  AS avg_stars,
    COUNT(r.id)                        AS review_count
  FROM public.menus m
  LEFT JOIN public.reviews r ON r.menu_id = m.id
  GROUP BY m.id, m.location_id;

COMMENT ON VIEW public.menu_stats IS '메뉴별 평균 별점 / 후기 수 집계 뷰';
