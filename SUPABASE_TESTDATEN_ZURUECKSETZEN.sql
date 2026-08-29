-- OrderBuddy: kompletter Reset aller Test-/Bewegungsdaten.
-- Stammdaten und Logins bleiben erhalten: Restaurants, Benutzer, Tische, Bereiche,
-- Speisekarte, Preise, Extras, Lieferzonen und Einstellungen.
begin;

-- Abrechnung / Bestellungen / Drucke
delete from public.bill_group_items;
delete from public.bill_groups;
delete from public.order_item_extras;
delete from public.order_items;
delete from public.print_job_items;
delete from public.print_jobs;
delete from public.table_sessions;

-- Gutscheine inkl. alter Testcodes
delete from public.voucher_events;
delete from public.vouchers;

-- Weitere Testdaten, sofern die Tabellen vorhanden sind
do $$
begin
  if to_regclass('public.manual_bookings') is not null then
    execute 'delete from public.manual_bookings';
  end if;
  if to_regclass('public.reservations') is not null then
    execute 'delete from public.reservations';
  end if;
  if to_regclass('public.day_exports') is not null then
    execute 'delete from public.day_exports';
  end if;
  if to_regclass('public.audit_log') is not null then
    execute 'delete from public.audit_log';
  end if;
  if to_regclass('public.inventory_movements') is not null then
    execute 'delete from public.inventory_movements';
  end if;
  if to_regclass('public.inventory_items') is not null then
    execute 'update public.inventory_items set current_stock=0, updated_at=now()';
  end if;
end $$;

-- Gutschein-Zähler für alle Testjahre zurücksetzen
update public.voucher_sequences set last_number=0;

commit;
