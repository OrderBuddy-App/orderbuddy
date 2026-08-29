-- OrderBuddy Lieferzonen (Legacy-Dateiname beibehalten, Inhalt generisch)
alter table public.table_sessions add column if not exists delivery_zone_id uuid;
alter table public.table_sessions add column if not exists delivery_fee numeric(10,2) not null default 0;

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name text not null,
  fee numeric(10,2) not null default 0 check (fee >= 0),
  active boolean not null default true,
  sort_order integer not null default 0,
  unique (restaurant_id, name)
);


create or replace function public.is_orderbuddy_admin(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.restaurant_users ru
    where ru.restaurant_id = p_restaurant_id
      and lower(ru.email) = lower(coalesce(auth.jwt() ->> 'email',''))
      and ru.active = true
      and ru.role in ('owner','admin')
  );
$$;

alter table public.delivery_zones enable row level security;
grant select, insert, update, delete on public.delivery_zones to authenticated;

drop policy if exists delivery_zones_read on public.delivery_zones;
create policy delivery_zones_read on public.delivery_zones
for select to authenticated using (public.user_has_restaurant_access(restaurant_id));

-- Nutzt die generische OrderBuddy-Adminfunktion, falls das Upgrade bereits ausgeführt wurde.
drop policy if exists delivery_zones_admin_write on public.delivery_zones;
create policy delivery_zones_admin_write on public.delivery_zones
for all to authenticated
using (public.is_orderbuddy_admin(restaurant_id))
with check (public.is_orderbuddy_admin(restaurant_id));

insert into public.delivery_zones (restaurant_id,name,fee,active,sort_order)
select r.id, x.name, 0, true, x.sort_order
from public.restaurants r
cross join (values
  ('Lieferzone 1',10),
  ('Lieferzone 2',20),
  ('Lieferzone 3',30),
  ('Lieferzone 4',40),
  ('Lieferzone 5',50)
) x(name,sort_order)
where not exists (select 1 from public.delivery_zones dz where dz.restaurant_id=r.id)
on conflict (restaurant_id,name) do nothing;
