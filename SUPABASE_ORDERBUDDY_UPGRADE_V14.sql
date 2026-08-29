-- OrderBuddy V14: einzelne abgeschlossene Bons sicher löschen
-- Einmalig im Supabase SQL Editor ausführen.
begin;

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

  -- Druckverknüpfungen zuerst entfernen.
  delete from public.print_job_items
   where print_job_id in (select id from public.print_jobs where session_id = p_session_id)
      or order_item_id in (select id from public.order_items where session_id = p_session_id);
  delete from public.print_jobs where session_id = p_session_id;

  -- Gutscheinereignisse/Gutscheine dieses Vorgangs entfernen.
  delete from public.voucher_events
   where voucher_id in (select id from public.vouchers where session_id = p_session_id);
  delete from public.vouchers where session_id = p_session_id;

  -- Abrechnung inklusive dokumentierter Zahlungsarten entfernen.
  delete from public.bill_group_payments
   where bill_group_id in (select id from public.bill_groups where session_id = p_session_id);
  delete from public.bill_group_items
   where bill_group_id in (select id from public.bill_groups where session_id = p_session_id);
  delete from public.bill_groups where session_id = p_session_id;

  -- Bestellpositionen und Extras entfernen.
  delete from public.order_item_extras
   where order_item_id in (select id from public.order_items where session_id = p_session_id);
  delete from public.order_items where session_id = p_session_id;

  -- Export-Markierung zurücksetzen, weil sich Tages-/Monatswerte geändert haben.
  delete from public.day_exports
   where restaurant_id = v_restaurant_id and business_date = v_business_date;

  delete from public.table_sessions where id = p_session_id;

  return jsonb_build_object('ok', true, 'business_date', v_business_date);
end;
$$;

grant execute on function public.delete_orderbuddy_closed_session(uuid) to authenticated;

commit;
