-- Löscht nur Test-/Bewegungsdaten. Stammdaten wie Speisekarte, Tische, Preise und Einstellungen bleiben erhalten.
begin;
delete from public.bill_group_items;
delete from public.bill_groups;
delete from public.order_items;
delete from public.voucher_events;
delete from public.vouchers;
delete from public.table_sessions;
delete from public.print_jobs;
update public.voucher_sequences set last_number=0 where year=2026;
update public.delivery_zones set name='Hummersen' where name='Himmersen';
commit;