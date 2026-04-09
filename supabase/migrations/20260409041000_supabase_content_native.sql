alter table public.discussion_posts enable row level security;
alter table public.book_categories enable row level security;
alter table public.books enable row level security;
alter table public.news_items enable row level security;
alter table public.kajian_items enable row level security;
alter table public.reels enable row level security;
alter table public.screeners enable row level security;
alter table public.consultation_categories enable row level security;
alter table public.sharia_experts enable row level security;
alter table public.consultation_sessions enable row level security;

drop policy if exists discussion_posts_read_all on public.discussion_posts;
create policy discussion_posts_read_all
on public.discussion_posts
for select
to authenticated, anon
using (true);

drop policy if exists discussion_posts_insert_self on public.discussion_posts;
create policy discussion_posts_insert_self
on public.discussion_posts
for insert
to authenticated
with check (user_id = public.current_profile_id());

drop policy if exists book_categories_read_active on public.book_categories;
create policy book_categories_read_active
on public.book_categories
for select
to authenticated, anon
using (is_active = true);

drop policy if exists books_read_published on public.books;
create policy books_read_published
on public.books
for select
to authenticated, anon
using (status = 'published');

drop policy if exists news_items_read_all on public.news_items;
create policy news_items_read_all
on public.news_items
for select
to authenticated, anon
using (true);

drop policy if exists kajian_items_read_active on public.kajian_items;
create policy kajian_items_read_active
on public.kajian_items
for select
to authenticated, anon
using (is_active = true);

drop policy if exists reels_read_active on public.reels;
create policy reels_read_active
on public.reels
for select
to authenticated, anon
using (is_active = true);

drop policy if exists screeners_read_all on public.screeners;
create policy screeners_read_all
on public.screeners
for select
to authenticated, anon
using (true);

drop policy if exists consultation_categories_read_all on public.consultation_categories;
create policy consultation_categories_read_all
on public.consultation_categories
for select
to authenticated, anon
using (true);

drop policy if exists sharia_experts_read_all on public.sharia_experts;
create policy sharia_experts_read_all
on public.sharia_experts
for select
to authenticated, anon
using (true);

drop policy if exists consultation_sessions_rw_self on public.consultation_sessions;
create policy consultation_sessions_rw_self
on public.consultation_sessions
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());
