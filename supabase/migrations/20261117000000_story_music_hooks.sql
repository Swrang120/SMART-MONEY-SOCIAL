-- Smart Money Social: admin-selected Story Music hooks
ALTER TABLE public.social_story_music_library
  ADD COLUMN IF NOT EXISTS music_start_seconds numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS music_end_seconds numeric(10,2),
  ADD COLUMN IF NOT EXISTS is_trending_hook boolean NOT NULL DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'social_story_music_library_hook_range_check'
      AND conrelid = 'public.social_story_music_library'::regclass
  ) THEN
    ALTER TABLE public.social_story_music_library
      ADD CONSTRAINT social_story_music_library_hook_range_check
      CHECK (
        music_start_seconds >= 0
        AND (music_end_seconds IS NULL OR music_end_seconds > music_start_seconds)
        AND (music_end_seconds IS NULL OR music_end_seconds - music_start_seconds BETWEEN 15 AND 30)
      );
  END IF;
END $$;
