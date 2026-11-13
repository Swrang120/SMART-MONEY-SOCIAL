-- Smart Money Social profile enhancements
-- Apply only to the Social project's public.social_profiles table.
-- This migration does not change authentication, RLS policies, or storage visibility.
alter table public.social_profiles
  add column if not exists cover_path text,
  add column if not exists relationship_status text,
  add column if not exists relationship_visibility text not null default 'private',
  add column if not exists phone_number text,
  add column if not exists phone_visibility text not null default 'private',
  add column if not exists contact_email text,
  add column if not exists email_visibility text not null default 'private',
  add column if not exists social_link_1 text,
  add column if not exists social_link_2 text,
  add column if not exists social_links_visibility text not null default 'private';

alter table public.social_profiles
  drop constraint if exists social_profiles_relationship_visibility_check,
  add constraint social_profiles_relationship_visibility_check
    check (relationship_visibility in ('public','private')),
  drop constraint if exists social_profiles_phone_visibility_check,
  add constraint social_profiles_phone_visibility_check
    check (phone_visibility in ('public','private')),
  drop constraint if exists social_profiles_email_visibility_check,
  add constraint social_profiles_email_visibility_check
    check (email_visibility in ('public','private')),
  drop constraint if exists social_profiles_social_links_visibility_check,
  add constraint social_profiles_social_links_visibility_check
    check (social_links_visibility in ('public','private')),
  drop constraint if exists social_profiles_relationship_status_check,
  add constraint social_profiles_relationship_status_check
    check (relationship_status is null or relationship_status in
      ('Single','In a relationship','Married','Engaged','It’s complicated'));

comment on column public.social_profiles.phone_number is
  'Optional profile contact; private by default. Do not expose unless visibility is public.';
comment on column public.social_profiles.contact_email is
  'Optional contact email; private by default. Do not expose unless visibility is public.';
comment on column public.social_profiles.social_link_1 is
  'First optional social profile link. At most two links are supported.';
comment on column public.social_profiles.social_link_2 is
  'Second optional social profile link. At most two links are supported.';
