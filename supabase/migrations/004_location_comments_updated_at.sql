-- ============================================================
-- 004 · location_comments 갱신 추적 (updated_at)
-- ------------------------------------------------------------
-- 댓글 수정 기능 추가에 따라 갱신 시각을 기록한다.
-- 멱등하게 동작한다.
-- ============================================================

ALTER TABLE public.location_comments
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN public.location_comments.updated_at IS '마지막 수정 시각';

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.set_location_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_location_comments_updated_at
  ON public.location_comments;

CREATE TRIGGER trg_location_comments_updated_at
  BEFORE UPDATE ON public.location_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_location_comments_updated_at();
