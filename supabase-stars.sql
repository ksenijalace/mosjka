-- The field of stars for The Hardest Kindness.
-- Paste into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
--
-- Only a name and two optional dates are stored for each star, and only when the
-- owner ticks the box to show them publicly. The table itself is closed; the site
-- can only call the two functions below.
-- To hide a star: Table Editor -> stars -> set "hidden" to true on that row.

create table if not exists public.stars (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 1 and 40),
  born date,
  died date,
  created_at timestamptz not null default now(),
  hidden boolean not null default false
);

alter table public.stars enable row level security;
revoke all on public.stars from anon, authenticated;

create or replace function public.light_star(p_name text, p_born date, p_died date)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(p_name);
  v_id bigint;
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
  -- A gentle brake against floods: at most 30 new stars every 10 minutes.
  if (select count(*) from public.stars where created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'busy';
  end if;
  -- The same dog lit twice keeps one star.
  select id into v_id from public.stars
   where lower(name) = lower(v_name) and born is not distinct from p_born and died is not distinct from p_died;
  if v_id is not null then
    return v_id;
  end if;
  insert into public.stars (name, born, died) values (v_name, p_born, p_died) returning id into v_id;
  return v_id;
end;
$$;

-- The first star stays first; the rest newest first.
create or replace function public.list_stars()
returns table (id bigint, name text, born date, died date)
language sql
security definer
set search_path = public
as $$
  select s.id, s.name, s.born, s.died
    from public.stars s
   where not s.hidden
   order by (s.id = (select min(id) from public.stars)) desc, s.created_at desc
   limit 1000;
$$;

revoke all on function public.light_star(text, date, date) from public;
revoke all on function public.list_stars() from public;
grant execute on function public.light_star(text, date, date) to anon;
grant execute on function public.list_stars() to anon;

-- Mosjka's star, the first one.
insert into public.stars (name, born, died)
select 'Mosjka', date '2011-03-22', date '2026-09-21'
 where not exists (select 1 from public.stars);
