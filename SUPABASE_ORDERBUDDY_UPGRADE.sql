-- OrderBuddy Upgrade: generische Lieferzonen + manuelle Monatsbuchungen
-- Einmalig im Supabase SQL Editor ausführen.

begin;

-- 1) Lieferzonen generisch benennen (bestehende Preise bleiben erhalten).
with ranked as (
  select id, row_number() over (partition by restaurant_id order by sort_order, name, id) as rn
  from public.delivery_zones
)
update public.delivery_zones dz
set name = 'Lieferzone ' || ranked.rn
from ranked
where dz.id = ranked.id
  and ranked.rn between 1 and 5;

-- 2) Generische Admin-Hilfsfunktion für neue OrderBuddy-Tabellen.
create or replace function public.is_orderbuddy_admin(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.restaurant_users ru
    where ru.restaurant_id = p_restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt() ->> 'email',''))
      and ru.active = true
      and ru.role in ('owner','admin')
  );
$$;

-- 3) Manuelle Buchungen, die außerhalb von OrderBuddy entstehen.
create table if not exists public.manual_bookings (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  booking_date date not null,
  category text not null check (category in ('geldtransit','privatentnahme','privateinlage','kosten')),
  direction text,
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  account text not null,
  counter_account text not null,
  bu_key text,
  created_by_email text,
  created_at timestamptz not null default now()
);

create index if not exists manual_bookings_restaurant_date_idx
  on public.manual_bookings (restaurant_id, booking_date);

alter table public.manual_bookings enable row level security;
grant select, insert, update, delete on public.manual_bookings to authenticated;

drop policy if exists manual_bookings_read on public.manual_bookings;
create policy manual_bookings_read on public.manual_bookings
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));

drop policy if exists manual_bookings_admin_write on public.manual_bookings;
create policy manual_bookings_admin_write on public.manual_bookings
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

commit;
