create extension if not exists pgcrypto;
create extension if not exists citext;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  legacy_mongo_id text not null unique,
  email citext,
  full_name text not null,
  role text not null default 'user',
  auth_provider text not null default 'local',
  email_verified boolean not null default false,
  avatar_url text,
  privy_user_id text,
  primary_wallet_address text,
  legacy_password_hash text,
  requires_password_reset boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_login_at timestamptz,
  migrated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists profiles_email_unique
  on public.profiles (email)
  where email is not null;

create unique index if not exists profiles_privy_user_unique
  on public.profiles (privy_user_id)
  where privy_user_id is not null;

create table if not exists public.user_wallets (
  id uuid primary key,
  legacy_mongo_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  supabase_user_id uuid,
  privy_user_id text,
  wallet_address text not null,
  wallet_type text not null default 'embedded',
  wallet_client text not null default 'privy',
  chain_type text not null default 'evm',
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists user_wallets_user_wallet_unique
  on public.user_wallets (user_id, wallet_address);

create index if not exists user_wallets_privy_user_idx
  on public.user_wallets (privy_user_id);

create table if not exists public.auth_migration_queue (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  legacy_mongo_id text not null unique,
  email citext,
  migration_status text not null default 'pending',
  requires_password_reset boolean not null default true,
  note text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classes (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  title text not null,
  description text,
  level text,
  image_url text,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.class_modules (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null,
  description text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists class_modules_class_sort_idx
  on public.class_modules (class_id, sort_order, created_at);

create table if not exists public.class_materials (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  module_id uuid not null references public.class_modules(id) on delete cascade,
  title text not null,
  content text,
  video_url text,
  sort_order integer not null default 0,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists class_materials_module_sort_idx
  on public.class_materials (module_id, sort_order, created_at);

create table if not exists public.quizzes (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  class_id uuid not null references public.classes(id) on delete cascade,
  question text not null,
  options jsonb not null default '{}'::jsonb,
  correct_answer text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.material_progress (
  id uuid primary key,
  legacy_mongo_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  material_id uuid not null references public.class_materials(id) on delete cascade,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, material_id)
);

create table if not exists public.quiz_submissions (
  id uuid primary key,
  legacy_mongo_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  answer text,
  is_correct boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists quiz_submissions_user_created_idx
  on public.quiz_submissions (user_id, created_at desc);

create table if not exists public.certificate_templates (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  class_id uuid not null references public.classes(id) on delete cascade,
  template_name text not null,
  description text,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists certificate_templates_class_unique
  on public.certificate_templates (class_id);

create table if not exists public.user_certificates (
  id uuid primary key,
  legacy_mongo_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  certificate_template_id uuid references public.certificate_templates(id) on delete set null,
  certificate_name text,
  certificate_number text,
  score_percent integer,
  download_url text,
  generated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, class_id)
);

create table if not exists public.portfolio_items (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  asset_name text not null,
  symbol text not null,
  quantity numeric(24, 8) not null default 0,
  purchase_price numeric(24, 8) not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists portfolio_items_user_idx
  on public.portfolio_items (user_id, created_at desc);

create table if not exists public.portfolio_history (
  id uuid primary key,
  legacy_mongo_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  portfolio_item_id uuid references public.portfolio_items(id) on delete set null,
  action text not null,
  asset_name text,
  symbol text,
  quantity numeric(24, 8),
  purchase_price numeric(24, 8),
  total_value numeric(24, 8),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists portfolio_history_user_created_idx
  on public.portfolio_history (user_id, created_at desc);

create table if not exists public.discussion_posts (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  user_id uuid references public.profiles(id) on delete set null,
  parent_post_id uuid references public.discussion_posts(id) on delete cascade,
  title text,
  body text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists discussion_posts_parent_created_idx
  on public.discussion_posts (parent_post_id, created_at);

create table if not exists public.book_categories (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  name text not null,
  slug text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.books (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  category_id uuid references public.book_categories(id) on delete set null,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  updated_by_profile_id uuid references public.profiles(id) on delete set null,
  title text not null,
  slug text not null unique,
  author text,
  description text,
  access text not null default 'gratis',
  status text not null default 'draft',
  language text not null default 'id',
  is_featured boolean not null default false,
  format_file text,
  drive_file_id text,
  cover_key text,
  file_key text,
  file_pdf text,
  file_name text,
  file_size_bytes bigint,
  storage_provider text,
  published_at timestamptz,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.news_items (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  title text not null,
  slug text not null unique,
  summary text,
  content text,
  content_blocks jsonb not null default '[]'::jsonb,
  source_url text not null,
  source_name text,
  image_url text,
  provider text,
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists news_items_source_url_unique
  on public.news_items (source_url);

create table if not exists public.kajian_items (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  title text not null,
  description text,
  youtube_url text,
  channel_name text,
  category text,
  duration_label text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists kajian_items_youtube_url_unique
  on public.kajian_items (youtube_url)
  where youtube_url is not null;

create table if not exists public.screeners (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  coin_name text not null,
  symbol text not null,
  status text,
  sharia_status text,
  fiqh_explanation text,
  scholar_reference text,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists screeners_symbol_unique
  on public.screeners (symbol);

create table if not exists public.consultation_categories (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  external_id text unique,
  name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sharia_experts (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  profile_id uuid references public.profiles(id) on delete set null,
  category_id uuid references public.consultation_categories(id) on delete set null,
  full_name text not null,
  email citext,
  specialization text,
  rating numeric(4, 2),
  total_review integer not null default 0,
  years_experience integer not null default 0,
  session_price numeric(12, 2) not null default 0,
  whatsapp_number text,
  is_online boolean not null default false,
  is_verified boolean not null default false,
  photo_url text,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists sharia_experts_email_unique
  on public.sharia_experts (email)
  where email is not null;

create table if not exists public.consultation_sessions (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  order_id text unique,
  user_id uuid references public.profiles(id) on delete set null,
  expert_id uuid references public.sharia_experts(id) on delete set null,
  status text not null default 'pending',
  price numeric(12, 2) not null default 0,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.reels (
  id uuid primary key,
  legacy_mongo_id text not null unique,
  sort_order integer not null default 0,
  title text not null,
  category text,
  arabic_quote text,
  translation text,
  source text,
  explanation text,
  audio_url text,
  tags jsonb not null default '[]'::jsonb,
  duration_seconds integer not null default 0,
  is_active boolean not null default true,
  extra_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'profiles',
    'user_wallets',
    'auth_migration_queue',
    'classes',
    'class_modules',
    'class_materials',
    'quizzes',
    'material_progress',
    'quiz_submissions',
    'certificate_templates',
    'user_certificates',
    'portfolio_items',
    'portfolio_history',
    'discussion_posts',
    'book_categories',
    'books',
    'news_items',
    'kajian_items',
    'screeners',
    'consultation_categories',
    'sharia_experts',
    'consultation_sessions',
    'reels'
  ]
  loop
    execute format('drop trigger if exists trg_%I_updated_at on public.%I', tbl, tbl);
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      tbl,
      tbl
    );
  end loop;
end $$;
