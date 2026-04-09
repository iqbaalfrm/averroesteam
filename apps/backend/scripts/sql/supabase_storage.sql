insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'pustaka-files',
    'pustaka-files',
    false,
    52428800,
    array['application/pdf', 'application/epub+zip']
  ),
  (
    'pustaka-covers',
    'pustaka-covers',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read pustaka covers" on storage.objects;
create policy "Public can read pustaka covers"
on storage.objects
for select
to public
using (bucket_id = 'pustaka-covers');

drop policy if exists "Authenticated can read pustaka files" on storage.objects;
create policy "Authenticated can read pustaka files"
on storage.objects
for select
to authenticated
using (bucket_id = 'pustaka-files');
