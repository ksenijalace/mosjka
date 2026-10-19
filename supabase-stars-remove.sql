-- Let the person who lit a star take it down again.
-- Paste into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- Each new star gets a private key that only the site of the person who lit it receives.
-- Taking a star down needs that key. Stars lit before this keep no key; you can still
-- hide those yourself in Table Editor -> stars -> hidden.

alter table public.stars add column if not exists secret text;

create or replace function public.light_star_v2(p_name text, p_born date, p_died date)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(p_name);
  v_id bigint;
  v_secret text;
begin
  if v_name is null or char_length(v_name) < 1 or char_length(v_name) > 40 then
    raise exception 'invalid name';
  end if;
  if v_name ~* '(https?:|www\.|@|<|>)' then
    raise exception 'invalid name';
  end if;
  if p_born is not null and (p_born < date '1980-01-01' or p_born > current_date) then
    raise exception 'invalid date';
  end if;
  if p_died is not null and (p_died > current_date or (p_born is not null and p_died < p_born)) then
    raise exception 'invalid date';
  end if;
  if (select count(*) from public.stars where created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'busy';
  end if;
  -- The same dog lit twice keeps one star; the key is never handed out a second time.
  select id into v_id from public.stars
   where lower(name) = lower(v_name) and born is not distinct from p_born and died is not distinct from p_died and not hidden;
  if v_id is not null then
    return jsonb_build_object('id', v_id, 'token', null);
  end if;
  v_secret := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.stars (name, born, died, secret) values (v_name, p_born, p_died, v_secret) returning id into v_id;
  return jsonb_build_object('id', v_id, 'token', v_secret);
end;
$$;

create or replace function public.remove_star(p_id bigint, p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_token is null or char_length(p_token) <> 64 then
    return false;
  end if;
  delete from public.stars where id = p_id and secret = p_token;
  return found;
end;
$$;

revoke all on function public.light_star_v2(text, date, date) from public;
revoke all on function public.remove_star(bigint, text) from public;
grant execute on function public.light_star_v2(text, date, date) to anon;
grant execute on function public.remove_star(bigint, text) to anon;
