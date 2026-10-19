-- Online history for The Hardest Kindness.
-- Paste into Supabase: SQL Editor -> New query -> Run.
--
-- The site never sends the nickname, birthday or PIN. It sends only a SHA-256
-- hash of them (64 hex characters), which is used as the key below.
-- The table itself is closed; the site can only call the two functions.

create table if not exists public.histories (
  key text primary key check (char_length(key) = 64),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.histories enable row level security;
revoke all on public.histories from anon, authenticated;

create or replace function public.get_history(p_key text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select data from public.histories where key = p_key;
$$;

create or replace function public.save_history(p_key text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_key !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid key';
  end if;
  if pg_column_size(p_data) > 500000 then
    raise exception 'history too large';
  end if;
  insert into public.histories (key, data, updated_at)
  values (p_key, p_data, now())
  on conflict (key) do update set data = excluded.data, updated_at = now();
end;
$$;

revoke all on function public.get_history(text) from public;
revoke all on function public.save_history(text, jsonb) from public;
grant execute on function public.get_history(text) to anon;
grant execute on function public.save_history(text, jsonb) to anon;
