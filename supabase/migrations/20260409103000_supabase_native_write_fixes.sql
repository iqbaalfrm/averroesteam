create extension if not exists pgcrypto;

alter table if exists public.discussion_posts
  alter column id set default gen_random_uuid();

alter table if exists public.consultation_sessions
  alter column id set default gen_random_uuid();

alter table if exists public.portfolio_items
  alter column legacy_mongo_id drop not null;

alter table if exists public.discussion_posts
  alter column legacy_mongo_id drop not null;

alter table if exists public.consultation_sessions
  alter column legacy_mongo_id drop not null;
