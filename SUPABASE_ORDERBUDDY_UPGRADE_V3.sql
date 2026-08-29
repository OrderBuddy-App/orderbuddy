-- OrderBuddy Upgrade V3
-- Standard-Wechselgeld pro Restaurant für den täglichen Bargeldsaldo.
-- Einmalig im Supabase SQL Editor ausführen.

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
