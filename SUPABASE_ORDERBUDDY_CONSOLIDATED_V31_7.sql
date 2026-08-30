-- OrderBuddy V31 – konsolidiertes, wiederholt ausführbares Upgrade
-- Basis: aktueller vollständiger Projektstand vom 30.08.2026.
-- Ziel: alle für diesen Stand benötigten Ergänzungen in EINEM SQL-Skript.
-- Bestehende Stamm-/Konfigurationsdaten werden nicht gelöscht.

begin;

-- ---------------------------------------------------------------------------
-- 1) Zentrale Admin-Prüfung
-- ---------------------------------------------------------------------------
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
      and lower(ru.email) = lower(coalesce((select auth.jwt()) ->> 'email',''))
      and ru.active = true
      and ru.role in ('owner','admin')
  );
$$;
revoke all on function public.is_orderbuddy_admin(uuid) from public, anon;
grant execute on function public.is_orderbuddy_admin(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Restaurant-/Session-/Positionsfelder
-- ---------------------------------------------------------------------------
alter table public.restaurants
  add column if not exists cash_start_amount numeric(12,2) not null default 0;

alter table public.restaurants drop constraint if exists restaurants_cash_start_amount_check;
alter table public.restaurants
  add constraint restaurants_cash_start_amount_check check (cash_start_amount >= 0);

grant update (cash_start_amount) on public.restaurants to authenticated;
drop policy if exists restaurants_orderbuddy_admin_cash_start on public.restaurants;
create policy restaurants_orderbuddy_admin_cash_start on public.restaurants
for update to authenticated
using (public.is_orderbuddy_admin(id))
with check (public.is_orderbuddy_admin(id));

alter table public.table_sessions
  add column if not exists ready_for_checkout boolean not null default false,
  add column if not exists restore_ready_on_revert boolean not null default false,
  add column if not exists reopened_from_checkout_at timestamptz null,
  add column if not exists historical_entry boolean not null default false,
  add column if not exists delivery_zone_id uuid null,
  add column if not exists delivery_fee numeric(12,2) not null default 0;

alter table public.table_sessions drop constraint if exists table_sessions_delivery_fee_check;
alter table public.table_sessions
  add constraint table_sessions_delivery_fee_check check (delivery_fee >= 0);

alter table public.order_items
  add column if not exists course text not null default 'main',
  add column if not exists dispatch_printed_at timestamptz null;

alter table public.order_items drop constraint if exists order_items_course_check;
alter table public.order_items
  add constraint order_items_course_check check (course in ('main','starter','together'));

-- ---------------------------------------------------------------------------
-- 3) Lieferzonen + kostenfreie Lieferung
-- ---------------------------------------------------------------------------
create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name text not null,
  postal_code text,
  fee numeric(12,2) not null default 0,
  free_delivery_minimum numeric(12,2) not null default 0,
  active boolean not null default true,
  sort_order integer not null default 0,
  unique (restaurant_id, name)
);

alter table public.delivery_zones
  add column if not exists postal_code text,
  add column if not exists free_delivery_minimum numeric(12,2) not null default 0;

alter table public.delivery_zones drop constraint if exists delivery_zones_postal_code_check;
alter table public.delivery_zones
  add constraint delivery_zones_postal_code_check
  check (postal_code is null or postal_code = '' or postal_code ~ '^[0-9]{5}$');

alter table public.delivery_zones drop constraint if exists delivery_zones_fee_check;
alter table public.delivery_zones
  add constraint delivery_zones_fee_check check (fee >= 0);

alter table public.delivery_zones drop constraint if exists delivery_zones_free_delivery_minimum_check;
alter table public.delivery_zones
  add constraint delivery_zones_free_delivery_minimum_check check (free_delivery_minimum >= 0);

alter table public.delivery_zones enable row level security;
grant select, insert, update, delete on public.delivery_zones to authenticated;

drop policy if exists delivery_zones_read on public.delivery_zones;
create policy delivery_zones_read on public.delivery_zones
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));

drop policy if exists delivery_zones_admin_write on public.delivery_zones;
create policy delivery_zones_admin_write on public.delivery_zones
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

-- FK erst ergänzen, wenn noch nicht vorhanden.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'table_sessions_delivery_zone_id_fkey'
      and conrelid = 'public.table_sessions'::regclass
  ) then
    alter table public.table_sessions
      add constraint table_sessions_delivery_zone_id_fkey
      foreign key (delivery_zone_id) references public.delivery_zones(id) on delete set null;
  end if;
end $$;

comment on column public.delivery_zones.free_delivery_minimum is
  'Brutto-Warenwert, ab dem die Lieferung in dieser Zone kostenfrei ist; 0 deaktiviert den Schwellenwert.';

-- ---------------------------------------------------------------------------
-- 4) Straßenverzeichnis je Lieferzone (mandantenfähig)
-- ---------------------------------------------------------------------------
create table if not exists public.delivery_zone_streets (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  delivery_zone_id uuid not null references public.delivery_zones(id) on delete cascade,
  street_name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (delivery_zone_id, street_name)
);
create index if not exists delivery_zone_streets_zone_idx
  on public.delivery_zone_streets(delivery_zone_id, active, sort_order, street_name);

alter table public.delivery_zone_streets enable row level security;
grant select, insert, update, delete on public.delivery_zone_streets to authenticated;

drop policy if exists delivery_zone_streets_read on public.delivery_zone_streets;
create policy delivery_zone_streets_read on public.delivery_zone_streets
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));

drop policy if exists delivery_zone_streets_admin_write on public.delivery_zone_streets;
create policy delivery_zone_streets_admin_write on public.delivery_zone_streets
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

-- Pilot-Konfiguration: PLZ ergänzen, wenn die fünf Ortsnamen bereits als Lieferzonen existieren.
update public.delivery_zones set postal_code='37647' where lower(trim(name))='polle' and coalesce(postal_code,'')='';
update public.delivery_zones set postal_code='32676' where lower(trim(name))='hummersen' and coalesce(postal_code,'')='';
update public.delivery_zones set postal_code='37647' where lower(trim(name))='brevörde' and coalesce(postal_code,'')='';
update public.delivery_zones set postal_code='37619' where lower(trim(name))='pegestorf' and coalesce(postal_code,'')='';
update public.delivery_zones set postal_code='37649' where lower(trim(name))='heinsen' and coalesce(postal_code,'')='';

-- Pilot-Straßenlisten. Zuordnung immer über exakte Kombination PLZ + Ort.
with street_data(postal_code, place_name, street_name, sort_order) as (
  values
  ('37647','Polle','Am Bracken',10),('37647','Polle','Amtsstraße',20),('37647','Polle','Angerweg',30),('37647','Polle','Bergstraße',40),('37647','Polle','Berliner Straße',50),('37647','Polle','Birkenweg',60),('37647','Polle','Brinkstraße',70),('37647','Polle','Burgblick',80),('37647','Polle','Burgstraße',90),('37647','Polle','Doktorgasse',100),('37647','Polle','Eversteiner Weg',110),('37647','Polle','Fährstraße',120),('37647','Polle','Försterweg',130),('37647','Polle','Gartenstraße',140),('37647','Polle','Heidbrink',150),('37647','Polle','Heimbergstraße',160),('37647','Polle','Heinser Straße',170),('37647','Polle','Hintere Straße',180),('37647','Polle','Höhenweg',190),('37647','Polle','Hohe Brücke',200),('37647','Polle','Hohe Feldstraße',210),('37647','Polle','Im Tappen',220),('37647','Polle','Im Teiche',230),('37647','Polle','Johann-Prigge-Weg',240),('37647','Polle','Klostergasse',250),('37647','Polle','Lindenbreite',260),('37647','Polle','Marktstraße',270),('37647','Polle','Mittelstraße',280),('37647','Polle','Mohrgasse',290),('37647','Polle','Mühlenweg',300),('37647','Polle','Postgasse',310),('37647','Polle','Pyrmonter Straße',320),('37647','Polle','Robrexer Bergweg',330),('37647','Polle','Robrexer Straße',340),('37647','Polle','Schäferhof',350),('37647','Polle','Schulstraße',360),('37647','Polle','Sonnenberg',370),('37647','Polle','Sonnenbergblick',380),('37647','Polle','Talweg',390),('37647','Polle','Weißenfeld',400),('37647','Polle','Wilmeröder Berg',410),('37647','Polle','Zimmergasse',420),('37647','Polle','Zum Tenterling',430),
  ('32676','Hummersen','Am Dorn',10),('32676','Hummersen','Am Lakenbach',20),('32676','Hummersen','Auf dem Kampe',30),('32676','Hummersen','Buchholzstraße',40),('32676','Hummersen','Detmolder Straße',50),('32676','Hummersen','Klingelborner Weg',60),('32676','Hummersen','Mühlenberg',70),('32676','Hummersen','Mühlenbergweg',80),('32676','Hummersen','Parkstraße',90),('32676','Hummersen','Tönsweg',100),('32676','Hummersen','Unterm Osterhagen',110),('32676','Hummersen','Vogelsang',120),('32676','Hummersen','Weißenfelder Weg',130),('32676','Hummersen','Weserberglandstraße',140),('32676','Hummersen','Winkelweg',150),
  ('37647','Brevörde','Bergstraße',10),('37647','Brevörde','Dornberg',20),('37647','Brevörde','Im Döhren',30),('37647','Brevörde','Kirchstraße',40),('37647','Brevörde','Meiborsser Straße',50),('37647','Brevörde','Obere Straße',60),('37647','Brevörde','Papenbreite',70),('37647','Brevörde','Riepenbrink',80),('37647','Brevörde','Untere Straße',90),
  ('37619','Pegestorf','Am Dreschplatz',10),('37619','Pegestorf','Am Kirschenberg',20),('37619','Pegestorf','Gartenstraße',30),('37619','Pegestorf','Hauptstraße',40),('37619','Pegestorf','Im Winkel',50),('37619','Pegestorf','Kirchweg',60),('37619','Pegestorf','Lichtensruh',70),('37619','Pegestorf','Lutterburg',80),('37619','Pegestorf','Maschhof',90),('37619','Pegestorf','Mittlere Straße',100),('37619','Pegestorf','Neues Tor',110),('37619','Pegestorf','Steinmühle',120),('37619','Pegestorf','Suestraße',130),('37619','Pegestorf','Weserstraße',140),('37619','Pegestorf','Worthstraße',150),('37619','Pegestorf','Zwischen Zäunen',160),
  ('37649','Heinsen','Auf der Breite',10),('37649','Heinsen','Bergstraße',20),('37649','Heinsen','Birkenweg',30),('37649','Heinsen','Dammstraße',40),('37649','Heinsen','Dangenstraße',50),('37649','Heinsen','Gartenstraße',60),('37649','Heinsen','Hauptstraße',70),('37649','Heinsen','Hopfenberg',80),('37649','Heinsen','In den Äckern',90),('37649','Heinsen','Klingenburg',100),('37649','Heinsen','Mittelstraße',110),('37649','Heinsen','Neue Straße',120),('37649','Heinsen','Oststraße',130),('37649','Heinsen','Rosenweg',140),('37649','Heinsen','Stollenweg',150),('37649','Heinsen','Südstraße',160),('37649','Heinsen','Weserstraße',170),('37649','Heinsen','Wilmeröderberg',180)
)
insert into public.delivery_zone_streets(restaurant_id, delivery_zone_id, street_name, sort_order)
select dz.restaurant_id, dz.id, sd.street_name, sd.sort_order
from street_data sd
join public.delivery_zones dz
  on trim(dz.postal_code)=sd.postal_code
 and lower(trim(dz.name))=lower(sd.place_name)
on conflict (delivery_zone_id, street_name)
do update set sort_order=excluded.sort_order, active=true;

-- ---------------------------------------------------------------------------
-- 5) Manuelle Buchungen + Mischzahlungen
-- ---------------------------------------------------------------------------
create table if not exists public.manual_bookings (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  booking_date date not null,
  category text not null,
  direction text,
  description text,
  amount numeric(12,2) not null,
  account text not null default '1590',
  counter_account text not null default '1000',
  bu_key text,
  created_by_email text,
  created_at timestamptz not null default now()
);

alter table public.manual_bookings alter column description drop not null;
alter table public.manual_bookings alter column account set default '1590';
alter table public.manual_bookings alter column counter_account set default '1000';
alter table public.manual_bookings drop constraint if exists manual_bookings_category_check;
alter table public.manual_bookings
  add constraint manual_bookings_category_check
  check (category in ('wechselgeld','geldtransit','privatentnahme','privateinlage','kosten'));
alter table public.manual_bookings drop constraint if exists manual_bookings_amount_check;
alter table public.manual_bookings
  add constraint manual_bookings_amount_check check (amount > 0);

create index if not exists manual_bookings_restaurant_date_idx
  on public.manual_bookings(restaurant_id, booking_date);
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

create table if not exists public.bill_group_payments (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  bill_group_id uuid not null references public.bill_groups(id) on delete cascade,
  payment_method text not null,
  amount numeric(12,2) not null,
  reference text,
  created_by_email text,
  created_at timestamptz not null default now()
);
alter table public.bill_group_payments drop constraint if exists bill_group_payments_payment_method_check;
alter table public.bill_group_payments
  add constraint bill_group_payments_payment_method_check
  check (payment_method in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other'));
alter table public.bill_group_payments drop constraint if exists bill_group_payments_amount_check;
alter table public.bill_group_payments
  add constraint bill_group_payments_amount_check check (amount > 0);
create index if not exists bill_group_payments_group_idx on public.bill_group_payments(bill_group_id);
create index if not exists bill_group_payments_restaurant_idx on public.bill_group_payments(restaurant_id, created_at);
alter table public.bill_group_payments enable row level security;
grant select, insert, update, delete on public.bill_group_payments to authenticated;

drop policy if exists bill_group_payments_read on public.bill_group_payments;
create policy bill_group_payments_read on public.bill_group_payments
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));

drop policy if exists bill_group_payments_write on public.bill_group_payments;
create policy bill_group_payments_write on public.bill_group_payments
for all to authenticated
using (public.user_has_restaurant_access(restaurant_id))
with check (public.user_has_restaurant_access(restaurant_id));

-- ---------------------------------------------------------------------------
-- 6) Veranstaltungen
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  event_date date not null,
  event_time time not null default '00:00',
  name text not null,
  guest_count integer not null default 1,
  mode text not null default 'package_and_alacarte',
  package_price_per_person numeric(12,2) not null default 0,
  split_mode text not null default '70_30',
  food_gross_per_person numeric(12,2) not null default 0,
  drink_gross_per_person numeric(12,2) not null default 0,
  payment_method text not null default 'cash',
  notes text,
  created_at timestamptz not null default now(),
  created_by_email text
);
alter table public.events drop constraint if exists events_guest_count_check;
alter table public.events add constraint events_guest_count_check check (guest_count > 0);
alter table public.events drop constraint if exists events_mode_check;
alter table public.events add constraint events_mode_check check (mode in ('alacarte','package','package_and_alacarte'));
alter table public.events drop constraint if exists events_split_mode_check;
alter table public.events add constraint events_split_mode_check check (split_mode in ('70_30','manual'));
alter table public.events drop constraint if exists events_payment_method_check;
alter table public.events add constraint events_payment_method_check check (payment_method in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other'));
alter table public.events drop constraint if exists events_nonnegative_amounts_check;
alter table public.events add constraint events_nonnegative_amounts_check check (
  package_price_per_person >= 0 and food_gross_per_person >= 0 and drink_gross_per_person >= 0
);
create index if not exists events_restaurant_date_idx on public.events(restaurant_id,event_date);

create table if not exists public.event_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id),
  quantity numeric(12,3) not null default 1,
  unit_price numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);
alter table public.event_items drop constraint if exists event_items_quantity_check;
alter table public.event_items add constraint event_items_quantity_check check (quantity > 0);
alter table public.event_items drop constraint if exists event_items_unit_price_check;
alter table public.event_items add constraint event_items_unit_price_check check (unit_price >= 0);
create index if not exists event_items_event_idx on public.event_items(event_id);

alter table public.events enable row level security;
alter table public.event_items enable row level security;
grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.event_items to authenticated;

drop policy if exists orderbuddy_events_access on public.events;
create policy orderbuddy_events_access on public.events
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

drop policy if exists orderbuddy_event_items_access on public.event_items;
create policy orderbuddy_event_items_access on public.event_items
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

comment on table public.events is
  'OrderBuddy-Veranstaltungen mit Pauschale und/oder zusätzlichen À-la-carte-Positionen.';

-- ---------------------------------------------------------------------------
-- 7) Sicheres Löschen einzelner abgeschlossener Bons
-- ---------------------------------------------------------------------------
create or replace function public.delete_orderbuddy_closed_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_restaurant_id uuid;
  v_business_date date;
  v_status text;
begin
  select restaurant_id, business_date, status
    into v_restaurant_id, v_business_date, v_status
  from public.table_sessions
  where id = p_session_id;

  if v_restaurant_id is null then
    raise exception 'Vorgang nicht gefunden.';
  end if;
  if v_status <> 'closed' then
    raise exception 'Nur abgeschlossene Vorgänge können gelöscht werden.';
  end if;
  if not public.is_orderbuddy_admin(v_restaurant_id) then
    raise exception 'Keine Berechtigung. Nur Owner/Admin.';
  end if;

  delete from public.print_job_items
   where print_job_id in (select id from public.print_jobs where session_id = p_session_id)
      or order_item_id in (select id from public.order_items where session_id = p_session_id);
  delete from public.print_jobs where session_id = p_session_id;

  delete from public.voucher_events
   where voucher_id in (select id from public.vouchers where session_id = p_session_id);
  delete from public.vouchers where session_id = p_session_id;

  delete from public.bill_group_payments
   where bill_group_id in (select id from public.bill_groups where session_id = p_session_id);
  delete from public.bill_group_items
   where bill_group_id in (select id from public.bill_groups where session_id = p_session_id);
  delete from public.bill_groups where session_id = p_session_id;

  delete from public.order_item_extras
   where order_item_id in (select id from public.order_items where session_id = p_session_id);
  delete from public.order_items where session_id = p_session_id;

  delete from public.day_exports
   where restaurant_id = v_restaurant_id and business_date = v_business_date;

  delete from public.table_sessions where id = p_session_id;

  return jsonb_build_object('ok', true, 'business_date', v_business_date);
end;
$$;
revoke all on function public.delete_orderbuddy_closed_session(uuid) from public, anon;
grant execute on function public.delete_orderbuddy_closed_session(uuid) to authenticated;

commit;

-- ===========================================================================
-- V31.5 – Veranstaltungen V-1 bis V-8
-- ===========================================================================
-- OrderBuddy V31.5 – Veranstaltungen V-1 bis V-8
-- Einmal im Supabase SQL Editor für das bestehende OrderBuddy-Production-Projekt ausführen.



alter table public.events add column if not exists slot_number smallint;
alter table public.events add column if not exists status text not null default 'open';
alter table public.events add column if not exists closed_at timestamptz;
alter table public.events add column if not exists closed_by_email text;

alter table public.events drop constraint if exists events_slot_number_check;
alter table public.events add constraint events_slot_number_check check (slot_number is null or slot_number between 1 and 8);
alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check check (status in ('open','closed'));

create unique index if not exists events_open_slot_unique
  on public.events(restaurant_id,event_date,slot_number)
  where status='open' and slot_number is not null;

-- Chef/Admin darf Konfiguration schreiben; Service darf sie nur lesen.
drop policy if exists orderbuddy_events_access on public.events;
drop policy if exists orderbuddy_events_read on public.events;
drop policy if exists orderbuddy_events_admin_write on public.events;
create policy orderbuddy_events_read on public.events
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));
create policy orderbuddy_events_admin_write on public.events
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

-- À-la-carte-Positionen dürfen Servicekräfte zur zugewiesenen Veranstaltung erfassen/stornieren.
drop policy if exists orderbuddy_event_items_access on public.event_items;
drop policy if exists orderbuddy_event_items_read on public.event_items;
drop policy if exists orderbuddy_event_items_insert on public.event_items;
drop policy if exists orderbuddy_event_items_delete on public.event_items;
create policy orderbuddy_event_items_read on public.event_items
for select to authenticated
using (public.user_has_restaurant_access(restaurant_id));
create policy orderbuddy_event_items_insert on public.event_items
for insert to authenticated
with check (public.user_has_restaurant_access(restaurant_id));
create policy orderbuddy_event_items_delete on public.event_items
for delete to authenticated
using (public.user_has_restaurant_access(restaurant_id));

create or replace function public.close_orderbuddy_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
  v_email text;
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_event.status='closed' then return jsonb_build_object('ok',true,'already_closed',true); end if;
  select email into v_email from auth.users where id=auth.uid();
  update public.events set status='closed',closed_at=now(),closed_by_email=v_email where id=p_event_id;
  return jsonb_build_object('ok',true,'event_id',p_event_id);
end;
$$;
revoke all on function public.close_orderbuddy_event(uuid) from public, anon;
grant execute on function public.close_orderbuddy_event(uuid) to authenticated;


-- ===========================================================================
-- V31.7 – Veranstaltungen vorbereiten, später an V-1 bis V-8 übergeben
-- ===========================================================================
begin;

alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check check (status in ('draft','open','closed'));

-- Ein V-Platz ist ein aktiver Serviceplatz und kann unabhängig vom Veranstaltungsdatum
-- nur einmal gleichzeitig belegt sein.
drop index if exists public.events_open_slot_unique;
create unique index events_open_slot_unique
  on public.events(restaurant_id,slot_number)
  where status='open' and slot_number is not null;

-- Service darf À-la-carte nur an aktuell übergebenen Veranstaltungen ändern.
drop policy if exists orderbuddy_event_items_insert on public.event_items;
drop policy if exists orderbuddy_event_items_delete on public.event_items;
create policy orderbuddy_event_items_insert on public.event_items
for insert to authenticated
with check (
  public.user_has_restaurant_access(restaurant_id)
  and exists (
    select 1 from public.events e
    where e.id=event_id and e.restaurant_id=restaurant_id
      and e.status='open' and e.slot_number is not null
  )
);
create policy orderbuddy_event_items_delete on public.event_items
for delete to authenticated
using (
  public.user_has_restaurant_access(restaurant_id)
  and exists (
    select 1 from public.events e
    where e.id=event_id and e.restaurant_id=restaurant_id
      and e.status='open' and e.slot_number is not null
  )
);

create table if not exists public.event_payments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  payment_method text not null,
  amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  created_by_email text
);
alter table public.event_payments drop constraint if exists event_payments_method_check;
alter table public.event_payments add constraint event_payments_method_check check (payment_method in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other'));
alter table public.event_payments drop constraint if exists event_payments_amount_check;
alter table public.event_payments add constraint event_payments_amount_check check (amount > 0);
create index if not exists event_payments_event_idx on public.event_payments(event_id);
alter table public.event_payments enable row level security;
grant select, insert, update, delete on public.event_payments to authenticated;
drop policy if exists orderbuddy_event_payments_read on public.event_payments;
create policy orderbuddy_event_payments_read on public.event_payments
for select to authenticated using (public.user_has_restaurant_access(restaurant_id));

-- Abschluss inkl. Einzel-/Mischzahlung. Service darf nur offene, übergebene Veranstaltungen abschließen.
create or replace function public.close_orderbuddy_event_with_payments(p_event_id uuid, p_payments jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
  v_email text;
  v_expected numeric(12,2);
  v_paid numeric(12,2);
  v_first_method text;
  v_count integer;
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_event.status='closed' then return jsonb_build_object('ok',true,'already_closed',true); end if;
  if v_event.status<>'open' or v_event.slot_number is null then raise exception 'Veranstaltung wurde noch nicht an den Service übergeben'; end if;
  if jsonb_typeof(p_payments)<>'array' or jsonb_array_length(p_payments)=0 then raise exception 'Mindestens eine Zahlungsart erforderlich'; end if;

  select round(
    (case when v_event.mode in ('package','package_and_alacarte') then v_event.package_price_per_person*v_event.guest_count else 0 end)
    + coalesce((select sum(quantity*unit_price) from public.event_items where event_id=p_event_id),0)
  ,2) into v_expected;

  select round(coalesce(sum((x->>'amount')::numeric),0),2), count(*), min(x->>'payment_method')
    into v_paid, v_count, v_first_method
  from jsonb_array_elements(p_payments) x;

  if exists(select 1 from jsonb_array_elements(p_payments) x where (x->>'payment_method') not in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other') or (x->>'amount')::numeric <= 0) then
    raise exception 'Ungültige Zahlungsart oder Betrag';
  end if;
  if abs(v_paid-v_expected)>0.005 then raise exception 'Zahlungssumme stimmt nicht mit Veranstaltungssumme überein'; end if;

  select email into v_email from auth.users where id=auth.uid();
  delete from public.event_payments where event_id=p_event_id;
  insert into public.event_payments(event_id,restaurant_id,payment_method,amount,created_by_email)
    select p_event_id,v_event.restaurant_id,x->>'payment_method',round((x->>'amount')::numeric,2),v_email
    from jsonb_array_elements(p_payments) x;

  update public.events
     set status='closed',closed_at=now(),closed_by_email=v_email,
         payment_method=case when v_count=1 then v_first_method else 'other' end
   where id=p_event_id;
  return jsonb_build_object('ok',true,'event_id',p_event_id,'gross',v_expected);
end;
$$;
revoke all on function public.close_orderbuddy_event_with_payments(uuid,jsonb) from public, anon;
grant execute on function public.close_orderbuddy_event_with_payments(uuid,jsonb) to authenticated;

commit;
