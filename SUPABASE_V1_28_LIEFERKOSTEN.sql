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

alter table public.delivery_zones enable row level security;
grant select, insert, update, delete on public.delivery_zones to authenticated;

drop policy if exists delivery_zones_read on public.delivery_zones;
create policy delivery_zones_read on public.delivery_zones
for select to authenticated using (public.user_has_restaurant_access(restaurant_id));

drop policy if exists delivery_zones_admin_write on public.delivery_zones;
create policy delivery_zones_admin_write on public.delivery_zones
for all to authenticated using (public.is_nova_admin()) with check (public.is_nova_admin());

insert into public.delivery_zones (restaurant_id,name,fee,active,sort_order)
select r.id,x.name,0,true,x.sort_order
from public.restaurants r
cross join (values ('Polle',10),('Himmersen',20),('Brevörde',30),('Pegestorf',40),('Heinsen',50)) x(name,sort_order)
where r.slug='nova'
on conflict (restaurant_id,name) do nothing;