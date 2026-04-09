create extension if not exists pgcrypto;

alter table if exists public.material_progress alter column id set default gen_random_uuid();
alter table if exists public.quiz_submissions alter column id set default gen_random_uuid();
alter table if exists public.user_certificates alter column id set default gen_random_uuid();
alter table if exists public.portfolio_items alter column id set default gen_random_uuid();
alter table if exists public.portfolio_history alter column id set default gen_random_uuid();
alter table if exists public.user_wallets alter column id set default gen_random_uuid();

create unique index if not exists quiz_submissions_user_quiz_unique
  on public.quiz_submissions (user_id, quiz_id);

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1),
    auth.uid()
  )
$$;

create or replace function public.ensure_profile()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_user_id uuid := auth.uid();
  v_claims jsonb := auth.jwt();
  v_user_meta jsonb := coalesce(v_claims -> 'user_metadata', '{}'::jsonb);
  v_app_meta jsonb := coalesce(v_claims -> 'app_metadata', '{}'::jsonb);
  v_email text := lower(nullif(coalesce(v_claims ->> 'email', ''), ''));
  v_name text := coalesce(
    nullif(v_user_meta ->> 'full_name', ''),
    nullif(v_user_meta ->> 'name', ''),
    nullif(v_claims ->> 'name', ''),
    case
      when coalesce((v_claims ->> 'is_anonymous')::boolean, false) then 'Pengguna Tamu'
      else 'Pengguna'
    end
  );
  v_role text := coalesce(
    nullif(v_user_meta ->> 'role', ''),
    nullif(v_app_meta ->> 'role', ''),
    case
      when coalesce((v_claims ->> 'is_anonymous')::boolean, false) then 'guest'
      else 'user'
    end
  );
  v_provider text := coalesce(nullif(v_app_meta ->> 'provider', ''), 'supabase');
  v_verified boolean := coalesce((v_claims ->> 'email_verified')::boolean, false);
  v_profile public.profiles;
begin
  if v_auth_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select *
  into v_profile
  from public.profiles
  where auth_user_id = v_auth_user_id
  limit 1;

  if v_profile.id is null then
    insert into public.profiles (
      id,
      auth_user_id,
      legacy_mongo_id,
      email,
      full_name,
      role,
      auth_provider,
      email_verified,
      metadata,
      created_at,
      updated_at,
      migrated_at
    )
    values (
      v_auth_user_id,
      v_auth_user_id,
      'auth:' || v_auth_user_id::text,
      v_email,
      v_name,
      v_role,
      v_provider,
      v_verified,
      v_user_meta,
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now())
    )
    returning * into v_profile;
  else
    update public.profiles
    set
      email = coalesce(v_email, email),
      full_name = coalesce(v_name, full_name),
      role = coalesce(nullif(v_profile.role, ''), v_role),
      auth_provider = coalesce(v_provider, auth_provider),
      email_verified = coalesce(v_verified, email_verified),
      metadata = coalesce(v_user_meta, metadata),
      last_login_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where id = v_profile.id
    returning * into v_profile;
  end if;

  return jsonb_build_object(
    'id', v_profile.id::text,
    'auth_user_id', v_profile.auth_user_id::text,
    'email', v_profile.email,
    'full_name', v_profile.full_name,
    'role', v_profile.role,
    'avatar_url', v_profile.avatar_url,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
end;
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_app_meta jsonb := coalesce(new.raw_app_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (
    id,
    auth_user_id,
    legacy_mongo_id,
    email,
    full_name,
    role,
    auth_provider,
    email_verified,
    metadata,
    created_at,
    updated_at,
    migrated_at
  )
  values (
    new.id,
    new.id,
    'auth:' || new.id::text,
    lower(new.email),
    coalesce(
      nullif(v_meta ->> 'full_name', ''),
      nullif(v_meta ->> 'name', ''),
      case when new.is_anonymous then 'Pengguna Tamu' else 'Pengguna' end
    ),
    coalesce(
      nullif(v_meta ->> 'role', ''),
      case when new.is_anonymous then 'guest' else 'user' end
    ),
    coalesce(nullif(v_app_meta ->> 'provider', ''), 'supabase'),
    coalesce(new.email_confirmed_at is not null, false),
    v_meta,
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    auth_user_id = excluded.auth_user_id,
    email = excluded.email,
    full_name = excluded.full_name,
    role = excluded.role,
    auth_provider = excluded.auth_provider,
    email_verified = excluded.email_verified,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.class_modules enable row level security;
alter table public.class_materials enable row level security;
alter table public.quizzes enable row level security;
alter table public.material_progress enable row level security;
alter table public.quiz_submissions enable row level security;
alter table public.certificate_templates enable row level security;
alter table public.user_certificates enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.portfolio_history enable row level security;
alter table public.user_wallets enable row level security;

drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self
on public.profiles
for select
to authenticated
using (auth_user_id = auth.uid() or id = auth.uid());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
on public.profiles
for update
to authenticated
using (auth_user_id = auth.uid() or id = auth.uid())
with check (auth_user_id = auth.uid() or id = auth.uid());

drop policy if exists classes_read_all on public.classes;
create policy classes_read_all
on public.classes
for select
to authenticated, anon
using (true);

drop policy if exists class_modules_read_all on public.class_modules;
create policy class_modules_read_all
on public.class_modules
for select
to authenticated, anon
using (true);

drop policy if exists class_materials_read_all on public.class_materials;
create policy class_materials_read_all
on public.class_materials
for select
to authenticated, anon
using (true);

drop policy if exists quizzes_read_all on public.quizzes;
create policy quizzes_read_all
on public.quizzes
for select
to authenticated, anon
using (true);

drop policy if exists certificate_templates_read_all on public.certificate_templates;
create policy certificate_templates_read_all
on public.certificate_templates
for select
to authenticated, anon
using (true);

drop policy if exists material_progress_rw_self on public.material_progress;
create policy material_progress_rw_self
on public.material_progress
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

drop policy if exists quiz_submissions_rw_self on public.quiz_submissions;
create policy quiz_submissions_rw_self
on public.quiz_submissions
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

drop policy if exists user_certificates_rw_self on public.user_certificates;
create policy user_certificates_rw_self
on public.user_certificates
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

drop policy if exists portfolio_items_rw_self on public.portfolio_items;
create policy portfolio_items_rw_self
on public.portfolio_items
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

drop policy if exists portfolio_history_rw_self on public.portfolio_history;
create policy portfolio_history_rw_self
on public.portfolio_history
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

drop policy if exists user_wallets_rw_self on public.user_wallets;
create policy user_wallets_rw_self
on public.user_wallets
for all
to authenticated
using (user_id = public.current_profile_id())
with check (user_id = public.current_profile_id());

create or replace function public.get_class_detail(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'id', c.id::text,
    'judul', c.title,
    'deskripsi', coalesce(c.description, ''),
    'modul', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id::text,
          'kelas_id', m.class_id::text,
          'judul', m.title,
          'deskripsi', coalesce(m.description, ''),
          'urutan', m.sort_order,
          'materi', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', mat.id::text,
                'modul_id', mat.module_id::text,
                'judul', mat.title,
                'konten', coalesce(mat.content, ''),
                'urutan', mat.sort_order
              )
              order by mat.sort_order, mat.created_at
            )
            from public.class_materials mat
            where mat.module_id = m.id
          ), '[]'::jsonb)
        )
        order by m.sort_order, m.created_at
      )
      from public.class_modules m
      where m.class_id = c.id
    ), '[]'::jsonb),
    'quiz', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', q.id::text,
          'kelas_id', q.class_id::text,
          'pertanyaan', q.question,
          'pilihan', q.options
        )
        order by q.created_at
      )
      from public.quizzes q
      where q.class_id = c.id
    ), '[]'::jsonb)
  )
  into result
  from public.classes c
  where c.id = p_class_id;

  return coalesce(result, '{}'::jsonb);
end;
$$;

create or replace function public.get_class_progress(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_profile_id();
  v_total_materi integer := 0;
  v_completed_materi integer := 0;
  v_completed_ids text[] := '{}';
  v_total_quiz integer := 0;
  v_answered_quiz integer := 0;
  v_correct_quiz integer := 0;
  v_score integer := 0;
begin
  perform public.ensure_profile();

  select count(*)
  into v_total_materi
  from public.class_materials mat
  join public.class_modules m on m.id = mat.module_id
  where m.class_id = p_class_id;

  select count(*), coalesce(array_agg(mp.material_id::text), '{}')
  into v_completed_materi, v_completed_ids
  from public.material_progress mp
  join public.class_materials mat on mat.id = mp.material_id
  join public.class_modules m on m.id = mat.module_id
  where mp.user_id = v_user_id
    and m.class_id = p_class_id;

  select count(*)
  into v_total_quiz
  from public.quizzes q
  where q.class_id = p_class_id;

  select
    count(*),
    count(*) filter (where qs.is_correct)
  into v_answered_quiz, v_correct_quiz
  from public.quiz_submissions qs
  join public.quizzes q on q.id = qs.quiz_id
  where qs.user_id = v_user_id
    and q.class_id = p_class_id;

  if v_total_quiz > 0 then
    v_score := round((v_correct_quiz::numeric / v_total_quiz::numeric) * 100);
  end if;

  return jsonb_build_object(
    'total_materi', v_total_materi,
    'completed_materi', v_completed_materi,
    'completed_materi_ids', to_jsonb(v_completed_ids),
    'progress_materi_percent',
      case when v_total_materi > 0 then round((v_completed_materi::numeric / v_total_materi::numeric) * 100) else 0 end,
    'total_quiz', v_total_quiz,
    'answered_quiz', v_answered_quiz,
    'correct_quiz', v_correct_quiz,
    'score_percent', v_score,
    'is_materi_complete', v_total_materi > 0 and v_completed_materi >= v_total_materi,
    'is_quiz_complete', v_total_quiz > 0 and v_answered_quiz >= v_total_quiz,
    'is_eligible_certificate',
      (v_total_materi > 0 and v_completed_materi >= v_total_materi)
      and (v_total_quiz > 0 and v_answered_quiz >= v_total_quiz and v_score >= 95)
  );
end;
$$;

create or replace function public.get_last_learning()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_profile_id();
  v_row record;
  v_completed_materi integer := 0;
  v_total_materi integer := 0;
begin
  perform public.ensure_profile();

  select
    mp.material_id,
    mat.title as material_title,
    m.class_id,
    c.title as class_title
  into v_row
  from public.material_progress mp
  join public.class_materials mat on mat.id = mp.material_id
  join public.class_modules m on m.id = mat.module_id
  join public.classes c on c.id = m.class_id
  where mp.user_id = v_user_id
  order by mp.completed_at desc nulls last, mp.created_at desc
  limit 1;

  if v_row.class_id is null then
    return '{}'::jsonb;
  end if;

  select count(*)
  into v_total_materi
  from public.class_materials mat
  join public.class_modules m on m.id = mat.module_id
  where m.class_id = v_row.class_id;

  select count(*)
  into v_completed_materi
  from public.material_progress mp
  join public.class_materials mat on mat.id = mp.material_id
  join public.class_modules m on m.id = mat.module_id
  where mp.user_id = v_user_id
    and m.class_id = v_row.class_id;

  return jsonb_build_object(
    'kelas_id', v_row.class_id::text,
    'kelas_judul', v_row.class_title,
    'completed_materi', v_completed_materi,
    'total_materi', v_total_materi,
    'progress_materi_percent',
      case when v_total_materi > 0 then round((v_completed_materi::numeric / v_total_materi::numeric) * 100) else 0 end,
    'next_materi_index', least(v_completed_materi + 1, greatest(v_total_materi, 1)),
    'last_materi_id', v_row.material_id::text,
    'last_materi_judul', v_row.material_title
  );
end;
$$;

create or replace function public.complete_material(p_material_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_profile_id();
begin
  perform public.ensure_profile();

  insert into public.material_progress (user_id, material_id, completed_at)
  values (v_user_id, p_material_id, timezone('utc', now()))
  on conflict (user_id, material_id)
  do update set
    completed_at = excluded.completed_at,
    updated_at = timezone('utc', now());

  return jsonb_build_object(
    'materi_id', p_material_id::text,
    'completed', true
  );
end;
$$;

create or replace function public.submit_quiz_answer(p_quiz_id uuid, p_answer text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_profile_id();
  v_quiz record;
  v_is_correct boolean := false;
begin
  perform public.ensure_profile();

  select *
  into v_quiz
  from public.quizzes
  where id = p_quiz_id;

  if v_quiz.id is null then
    raise exception 'Quiz tidak ditemukan';
  end if;

  v_is_correct := lower(trim(coalesce(p_answer, ''))) = lower(trim(coalesce(v_quiz.correct_answer, '')));

  insert into public.quiz_submissions (user_id, quiz_id, answer, is_correct)
  values (v_user_id, p_quiz_id, p_answer, v_is_correct)
  on conflict (user_id, quiz_id)
  do update set
    answer = excluded.answer,
    is_correct = excluded.is_correct,
    updated_at = timezone('utc', now());

  return jsonb_build_object(
    'quiz_id', p_quiz_id::text,
    'jawaban_pengguna', coalesce(p_answer, ''),
    'jawaban_benar', coalesce(v_quiz.correct_answer, ''),
    'benar', v_is_correct
  );
end;
$$;

create or replace function public.generate_certificate(p_class_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_profile_id();
  v_progress jsonb;
  v_class record;
  v_template record;
  v_score integer := 0;
  v_number text;
  v_cert record;
begin
  perform public.ensure_profile();

  select * into v_class from public.classes where id = p_class_id;
  if v_class.id is null then
    raise exception 'Kelas tidak ditemukan';
  end if;

  select * into v_template from public.certificate_templates where class_id = p_class_id;
  v_progress := public.get_class_progress(p_class_id);
  v_score := coalesce((v_progress ->> 'score_percent')::integer, 0);

  if coalesce((v_progress ->> 'is_eligible_certificate')::boolean, false) is not true then
    raise exception 'Belum memenuhi syarat sertifikat';
  end if;

  v_number := 'AVR-' || to_char(timezone('utc', now()), 'YYYYMMDDHH24MISS') || '-' || upper(substr(replace(p_class_id::text, '-', ''), 1, 6));

  insert into public.user_certificates (
    user_id,
    class_id,
    certificate_template_id,
    certificate_name,
    certificate_number,
    score_percent,
    generated_at
  )
  values (
    v_user_id,
    p_class_id,
    v_template.id,
    coalesce(v_template.template_name, 'Sertifikat Kelulusan ' || v_class.title),
    v_number,
    v_score,
    timezone('utc', now())
  )
  on conflict (user_id, class_id)
  do update set
    certificate_template_id = excluded.certificate_template_id,
    certificate_name = excluded.certificate_name,
    certificate_number = excluded.certificate_number,
    score_percent = excluded.score_percent,
    generated_at = excluded.generated_at,
    updated_at = timezone('utc', now())
  returning * into v_cert;

  return jsonb_build_object(
    'kelas_id', p_class_id::text,
    'kelas', v_class.title,
    'nama_sertifikat', coalesce(v_cert.certificate_name, 'Sertifikat'),
    'nomor', coalesce(v_cert.certificate_number, ''),
    'score_percent', coalesce(v_cert.score_percent, 0),
    'generated_at', v_cert.generated_at,
    'download_url', v_cert.download_url
  );
end;
$$;

grant execute on function public.ensure_profile() to authenticated;
grant execute on function public.get_class_detail(uuid) to authenticated, anon;
grant execute on function public.get_class_progress(uuid) to authenticated;
grant execute on function public.get_last_learning() to authenticated;
grant execute on function public.complete_material(uuid) to authenticated;
grant execute on function public.submit_quiz_answer(uuid, text) to authenticated;
grant execute on function public.generate_certificate(uuid) to authenticated;
