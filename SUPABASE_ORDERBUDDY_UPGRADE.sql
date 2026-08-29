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

-- OrderBuddy Upgrade V2: Zahlungsarten, Bargeldsaldo und Zusatzbons
begin;

-- Manuelle Buchungen: optionaler Text + Wechselgeld/Kassenstart.
alter table public.manual_bookings alter column description drop not null;
alter table public.manual_bookings drop constraint if exists manual_bookings_category_check;
alter table public.manual_bookings
  add constraint manual_bookings_category_check
  check (category in ('wechselgeld','geldtransit','privatentnahme','privateinlage','kosten'));

-- Pro Teilabrechnung können eine oder mehrere Zahlungsarten dokumentiert werden.
create table if not exists public.bill_group_payments (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  bill_group_id uuid not null references public.bill_groups(id) on delete cascade,
  payment_method text not null check (payment_method in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other')),
  amount numeric(12,2) not null check (amount > 0),
  reference text,
  created_by_email text,
  created_at timestamptz not null default now()
);
create index if not exists bill_group_payments_group_idx on public.bill_group_payments (bill_group_id);
create index if not exists bill_group_payments_restaurant_idx on public.bill_group_payments (restaurant_id, created_at);
alter table public.bill_group_payments enable row level security;
grant select, insert, update, delete on public.bill_group_payments to authenticated;
drop policy if exists bill_group_payments_read on public.bill_group_payments;
create policy bill_group_payments_read on public.bill_group_payments
for select to authenticated using (public.user_has_restaurant_access(restaurant_id));
drop policy if exists bill_group_payments_write on public.bill_group_payments;
create policy bill_group_payments_write on public.bill_group_payments
for all to authenticated
using (public.user_has_restaurant_access(restaurant_id))
with check (public.user_has_restaurant_access(restaurant_id));

-- Separater Druckstatus für Fahrer-/Abholbon, damit Nachbestellungen nur neue Positionen ausgeben.
alter table public.order_items add column if not exists dispatch_printed_at timestamptz;

commit;

-- OrderBuddy Upgrade V3: Standard-Wechselgeld pro Restaurant
begin;
alter table public.restaurants
  add column if not exists cash_start_amount numeric(12,2) not null default 0
  check (cash_start_amount >= 0);
grant update (cash_start_amount) on public.restaurants to authenticated;
drop policy if exists restaurants_orderbuddy_admin_cash_start on public.restaurants;
create policy restaurants_orderbuddy_admin_cash_start on public.restaurants
for update to authenticated
using (public.is_orderbuddy_admin(id))
with check (public.is_orderbuddy_admin(id));
commit;
