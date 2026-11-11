alter table public.profiles
  add column if not exists username text;

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username))
  where username is not null;

drop trigger if exists zzz_profiles_username_from_auth on auth.users;
drop function if exists public.sync_profile_username_from_auth();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_first boolean;
  normalized_username text;
begin
  normalized_username := lower(
    nullif(btrim(new.raw_user_meta_data ->> 'username'), '')
  );

  if normalized_username is null then
    raise exception 'Username is required';
  elsif normalized_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Username must be 3 to 24 letters, numbers, or underscores';
  end if;

  select not exists (select 1 from public.profiles) into is_first;

  insert into public.profiles (id, username, full_name, role, status)
  values (
    new.id,
    normalized_username,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      normalized_username
    ),
    case when is_first then 'admin' else 'user' end,
    case when is_first then 'approved' else 'pending' end
  );

  return new;
end;
$$;
