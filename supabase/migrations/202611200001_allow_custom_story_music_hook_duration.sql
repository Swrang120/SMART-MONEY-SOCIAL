-- Allow admins to select hook segments of any positive duration.
-- The previous 15–30 second database constraint blocked user-selected ranges.
ALTER TABLE public.social_story_music_library
  DROP CONSTRAINT IF EXISTS social_story_music_library_hook_range_check;

ALTER TABLE public.social_story_music_library
  ADD CONSTRAINT social_story_music_library_hook_range_check
  CHECK (
    music_start_seconds >= 0
    AND (music_end_seconds IS NULL OR music_end_seconds > music_start_seconds)
  );
