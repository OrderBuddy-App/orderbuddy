-- OrderBuddy V30 – konsolidiertes Upgrade
-- Ergänzt ausschließlich fehlende Felder/Tabellen und ist wiederholt ausführbar.

alter table public.table_sessions
  add column if not exists restore_ready_on_revert boolean not null default false,
  add column if not exists reopened_from_checkout_at timestamptz null,
  add column if not exists historical_entry boolean not null default false;

alter table public.delivery_zones
  add column if not exists postal_code text,
  add column if not exists free_delivery_minimum numeric(12,2) not null default 0;

alter table public.delivery_zones
  drop constraint if exists delivery_zones_postal_code_check;
alter table public.delivery_zones
  add constraint delivery_zones_postal_code_check
  check (postal_code is null or postal_code = '' or postal_code ~ '^[0-9]{5}$');

alter table public.delivery_zones
  drop constraint if exists delivery_zones_free_delivery_minimum_check;
alter table public.delivery_zones
  add constraint delivery_zones_free_delivery_minimum_check
  check (free_delivery_minimum >= 0);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  event_date date not null,
  event_time time not null default '00:00',
  name text not null,
  guest_count integer not null default 1 check (guest_count > 0),
  mode text not null default 'package_and_alacarte' check (mode in ('alacarte','package','package_and_alacarte')),
  package_price_per_person numeric(12,2) not null default 0 check (package_price_per_person >= 0),
  split_mode text not null default '70_30' check (split_mode in ('70_30','manual')),
  food_gross_per_person numeric(12,2) not null default 0 check (food_gross_per_person >= 0),
  drink_gross_per_person numeric(12,2) not null default 0 check (drink_gross_per_person >= 0),
  payment_method text not null default 'cash',
  notes text,
  created_at timestamptz not null default now(),
  created_by_email text
);

create index if not exists events_restaurant_date_idx on public.events(restaurant_id,event_date);

create table if not exists public.event_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id),
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit_price numeric(12,2) not null default 0 check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create index if not exists event_items_event_idx on public.event_items(event_id);

-- RLS übernimmt die bestehende Restaurant-Logik. Falls RLS auf den neuen Tabellen aktiv sein soll,
-- werden einfache Policies auf Basis der vorhandenen restaurant_users-Zuordnung angelegt.
alter table public.events enable row level security;
alter table public.event_items enable row level security;

drop policy if exists orderbuddy_events_access on public.events;
create policy orderbuddy_events_access on public.events
for all using (
  exists (
    select 1 from public.restaurant_users ru
    where ru.restaurant_id = events.restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt()->>'email',''))
      and ru.active = true
  )
) with check (
  exists (
    select 1 from public.restaurant_users ru
    where ru.restaurant_id = events.restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt()->>'email',''))
      and ru.active = true
  )
);

drop policy if exists orderbuddy_event_items_access on public.event_items;
create policy orderbuddy_event_items_access on public.event_items
for all using (
  exists (
    select 1 from public.restaurant_users ru
    where ru.restaurant_id = event_items.restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt()->>'email',''))
      and ru.active = true
  )
) with check (
  exists (
    select 1 from public.restaurant_users ru
    where ru.restaurant_id = event_items.restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt()->>'email',''))
      and ru.active = true
  )
);

grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.event_items to authenticated;

comment on column public.delivery_zones.free_delivery_minimum is
  'Brutto-Warenwert, ab dem die Lieferung in dieser Zone kostenfrei ist; 0 deaktiviert den Schwellenwert.';
comment on table public.events is
  'OrderBuddy-Veranstaltungen mit Pauschale und/oder zusätzlichen À-la-carte-Positionen.';
