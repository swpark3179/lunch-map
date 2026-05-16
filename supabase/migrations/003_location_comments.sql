-- ============================================================
-- 003 · 식당 단위 댓글 (location_comments)
-- ------------------------------------------------------------
-- 장소 상세 화면 재설계에 맞춰 메뉴 단위 별점/후기 모델을
-- "식당 단위 댓글" 단일 목록으로 단순화한다.
--
-- 기존 reviews 데이터는 menus.location_id 를 통해 location_comments
-- 로 이관한 뒤, reviews 테이블 및 menu_stats 뷰를 제거한다.
-- 마이그레이션은 멱등하게 동작한다.
-- ============================================================

-- 1. 새 테이블
CREATE TABLE IF NOT EXISTS public.location_comments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id  UUID NOT NULL REFERENCES public.locations(id) ON DELETE CASCADE,
  user_name    TEXT NOT NULL DEFAULT '익명',
  body         TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_location_comments_location_id
  ON public.location_comments (location_id);
CREATE INDEX IF NOT EXISTS idx_location_comments_created_at
  ON public.location_comments (created_at DESC);

COMMENT ON TABLE  public.location_comments            IS '식당 단위 댓글';
COMMENT ON COLUMN public.location_comments.location_id IS '대상 식당 ID (FK)';
COMMENT ON COLUMN public.location_comments.body        IS '댓글 본문';

ALTER TABLE public.location_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "location_comments_select" ON public.location_comments;
DROP POLICY IF EXISTS "location_comments_insert" ON public.location_comments;
DROP POLICY IF EXISTS "location_comments_update" ON public.location_comments;
DROP POLICY IF EXISTS "location_comments_delete" ON public.location_comments;

CREATE POLICY "location_comments_select" ON public.location_comments FOR SELECT USING (true);
CREATE POLICY "location_comments_insert" ON public.location_comments FOR INSERT
  TO anon, authenticated WITH CHECK (true);
CREATE POLICY "location_comments_update" ON public.location_comments FOR UPDATE
  TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "location_comments_delete" ON public.location_comments FOR DELETE
  TO anon, authenticated USING (true);

-- 2. 기존 reviews → location_comments 이관 (best-effort)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'reviews'
  ) THEN
    INSERT INTO public.location_comments (id, location_id, user_name, body, created_at)
    SELECT
      r.id,
      m.location_id,
      COALESCE(r.user_name, '익명'),
      COALESCE(NULLIF(r.comment, ''), '★ ' || r.stars::text),
      r.created_at
    FROM public.reviews r
    JOIN public.menus   m ON m.id = r.menu_id
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- 3. 더 이상 사용하지 않는 뷰/테이블 제거
DROP VIEW  IF EXISTS public.menu_stats;
DROP TABLE IF EXISTS public.reviews;
