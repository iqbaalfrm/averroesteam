create or replace function public.issue_auth_otp_challenge(
  p_email text,
  p_purpose text,
  p_auth_user_id uuid default null,
  p_full_name text default null,
  p_ttl_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_purpose text := lower(trim(coalesce(p_purpose, '')));
  v_otp text := lpad((floor(random() * 10000))::integer::text, 4, '0');
  v_expires_at timestamptz := timezone('utc', now()) + make_interval(mins => greatest(coalesce(p_ttl_minutes, 10), 1));
  v_row public.auth_otp_challenges;
begin
  if v_email = '' then
    raise exception 'Email wajib diisi';
  end if;

  if v_purpose not in ('signup', 'recovery') then
    raise exception 'Mode OTP tidak valid';
  end if;

  insert into public.auth_otp_challenges (
    email,
    purpose,
    auth_user_id,
    otp_hash,
    full_name,
    attempt_count,
    resend_count,
    max_attempts,
    expires_at,
    last_sent_at,
    verified_at,
    consumed_at,
    metadata,
    updated_at
  )
  values (
    v_email,
    v_purpose,
    p_auth_user_id,
    extensions.crypt(v_otp, extensions.gen_salt('bf')),
    nullif(trim(coalesce(p_full_name, '')), ''),
    0,
    0,
    5,
    v_expires_at,
    timezone('utc', now()),
    null,
    null,
    jsonb_build_object('otp_length', 4),
    timezone('utc', now())
  )
  on conflict (email, purpose)
  do update set
    auth_user_id = coalesce(excluded.auth_user_id, public.auth_otp_challenges.auth_user_id),
    otp_hash = excluded.otp_hash,
    full_name = coalesce(excluded.full_name, public.auth_otp_challenges.full_name),
    attempt_count = 0,
    resend_count = public.auth_otp_challenges.resend_count + 1,
    max_attempts = excluded.max_attempts,
    expires_at = excluded.expires_at,
    last_sent_at = excluded.last_sent_at,
    verified_at = null,
    consumed_at = null,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now())
  returning * into v_row;

  return jsonb_build_object(
    'challenge_id', v_row.id::text,
    'email', v_row.email,
    'purpose', v_row.purpose,
    'otp', v_otp,
    'expires_at', v_row.expires_at,
    'otp_length', 4
  );
end;
$$;

create or replace function public.verify_auth_otp_challenge(
  p_email text,
  p_purpose text,
  p_otp text,
  p_consume boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_purpose text := lower(trim(coalesce(p_purpose, '')));
  v_otp text := trim(coalesce(p_otp, ''));
  v_row public.auth_otp_challenges;
  v_remaining_attempts integer;
begin
  select *
  into v_row
  from public.auth_otp_challenges
  where email = v_email
    and purpose = v_purpose
  for update;

  if v_row.id is null then
    return jsonb_build_object(
      'valid', false,
      'reason', 'otp_not_found',
      'message', 'Kode OTP tidak ditemukan'
    );
  end if;

  if v_row.consumed_at is not null then
    return jsonb_build_object(
      'valid', false,
      'reason', 'otp_already_used',
      'message', 'Kode OTP sudah digunakan'
    );
  end if;

  if v_row.expires_at < timezone('utc', now()) then
    return jsonb_build_object(
      'valid', false,
      'reason', 'otp_expired',
      'message', 'Kode OTP sudah kedaluwarsa'
    );
  end if;

  if v_row.attempt_count >= v_row.max_attempts then
    return jsonb_build_object(
      'valid', false,
      'reason', 'otp_attempts_exceeded',
      'message', 'Percobaan OTP melebihi batas'
    );
  end if;

  if extensions.crypt(v_otp, v_row.otp_hash) = v_row.otp_hash then
    update public.auth_otp_challenges
    set
      verified_at = coalesce(verified_at, timezone('utc', now())),
      consumed_at = case when p_consume then timezone('utc', now()) else consumed_at end,
      updated_at = timezone('utc', now())
    where id = v_row.id
    returning * into v_row;

    return jsonb_build_object(
      'valid', true,
      'challenge_id', v_row.id::text,
      'auth_user_id', case when v_row.auth_user_id is not null then v_row.auth_user_id::text else null end,
      'email', v_row.email,
      'purpose', v_row.purpose,
      'full_name', v_row.full_name,
      'expires_at', v_row.expires_at
    );
  end if;

  update public.auth_otp_challenges
  set
    attempt_count = attempt_count + 1,
    updated_at = timezone('utc', now())
  where id = v_row.id
  returning greatest(max_attempts - attempt_count, 0) into v_remaining_attempts;

  return jsonb_build_object(
    'valid', false,
    'reason', 'otp_invalid',
    'message', 'Kode OTP tidak valid',
    'remaining_attempts', v_remaining_attempts
  );
end;
$$;
