-- Allow signed-in Social members to read active Story Music catalog rows
-- and stream only files uploaded under */stories/library/* in the private bucket.
ALTER TABLE public.social_story_music_library ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON TABLE public.social_story_music_library TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'social_story_music_library'
      AND policyname = 'social_story_music_members_read_active'
  ) THEN
    CREATE POLICY social_story_music_members_read_active
      ON public.social_story_music_library
      FOR SELECT
      TO authenticated
      USING (is_active = true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'social_story_music_members_stream_library'
  ) THEN
    CREATE POLICY social_story_music_members_stream_library
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'smart-money-social'
        AND (storage.foldername(name))[2] = 'stories'
        AND (storage.foldername(name))[3] = 'library'
      );
  END IF;
END
$$;
