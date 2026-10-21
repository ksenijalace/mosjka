-- Usage numbers for The Hardest Kindness: counts only, never anything anyone wrote.
-- Paste into Supabase: SQL Editor -> New query -> Run.
--
-- Anyone with the site's public key can call usage_stats(), so it returns
-- nothing but totals: how many saved histories use each part of the site.

create or replace function public.usage_stats()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with h as (
    select data, updated_at,
      coalesce(data->'days', '{}'::jsonb) not in ('{}', '[]', 'null') as has_days,
      coalesce(data->'letters', '{}'::jsonb) not in ('{}', '[]', 'null') as has_letters,
      coalesce(data->'journey', '{}'::jsonb) not in ('{}', '[]', 'null') as has_journey,
      coalesce(data->'checklist', '{}'::jsonb) not in ('{}', '[]', 'null') as has_checklist,
      coalesce(data->'exercises', '{}'::jsonb) not in ('{}', '[]', 'null') as has_exercises,
      coalesce(data->'portrait'->'answers', '{}'::jsonb) not in ('{}', '[]', 'null') as has_portrait
    from public.histories
  )
  select jsonb_build_object(
    'histories', count(*),
    'active_7_days', count(*) filter (where updated_at > now() - interval '7 days'),
    'active_30_days', count(*) filter (where updated_at > now() - interval '30 days'),
    'daily_diary', count(*) filter (where has_days),
    'letters', count(*) filter (where has_letters),
    'path_30_days', count(*) filter (where has_journey),
    'checklist', count(*) filter (where has_checklist),
    'try_this_answers', count(*) filter (where has_exercises),
    'tell_me_about_them', count(*) filter (where has_portrait),
    'with_breed', count(*) filter (where coalesce(data->'profile'->>'breed', '') <> ''),
    'stage_not_sure_yet', count(*) filter (where data->'profile'->>'stage' = 'deciding'),
    'stage_day_is_near', count(*) filter (where data->'profile'->>'stage' = 'decided'),
    'said_goodbye', count(*) filter (where coalesce(data->'profile'->>'goodbye', '') <> ''),
    'stars', (select count(*) from public.stars),
    'last_saved', max(updated_at)
  ) from h;
$$;

revoke all on function public.usage_stats() from public;
grant execute on function public.usage_stats() to anon, authenticated;
