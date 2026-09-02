-- OrderBuddy V32 – konsolidiertes Upgrade auf Basis des aktuell hochgeladenen Projektstands.
-- Wiederholt ausführbar. Bestehende Stamm-/Konfigurationsdaten werden nicht gelöscht.

begin;

-- ---------------------------------------------------------------------------
-- 1) Gutscheine: fehlende Datenbankbasis + Veranstaltung-Verknüpfung
-- ---------------------------------------------------------------------------
create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  session_id uuid null references public.table_sessions(id) on delete cascade,
  event_id uuid null references public.events(id) on delete cascade,
  voucher_number text not null,
  original_value numeric(12,2) not null,
  remaining_value numeric(12,2) not null,
  status text not null default 'active',
  note text,
  issued_at timestamptz not null default now(),
  created_by_email text
);

alter table public.vouchers add column if not exists restaurant_id uuid;
alter table public.vouchers add column if not exists session_id uuid;
alter table public.vouchers add column if not exists event_id uuid;
alter table public.vouchers add column if not exists voucher_number text;
alter table public.vouchers add column if not exists original_value numeric(12,2);
alter table public.vouchers add column if not exists remaining_value numeric(12,2);
alter table public.vouchers add column if not exists status text default 'active';
alter table public.vouchers add column if not exists note text;
alter table public.vouchers add column if not exists issued_at timestamptz default now();
alter table public.vouchers add column if not exists created_by_email text;

-- FK nur ergänzen, wenn sie noch nicht existieren.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='vouchers_event_id_fkey' and conrelid='public.vouchers'::regclass
  ) then
    alter table public.vouchers add constraint vouchers_event_id_fkey
      foreign key (event_id) references public.events(id) on delete cascade;
  end if;
end $$;

create unique index if not exists vouchers_restaurant_number_uidx
  on public.vouchers(restaurant_id, voucher_number);
create index if not exists vouchers_session_idx on public.vouchers(session_id);
create index if not exists vouchers_event_idx on public.vouchers(event_id);
create index if not exists vouchers_issued_idx on public.vouchers(restaurant_id, issued_at);

alter table public.vouchers enable row level security;
grant select, insert, update, delete on public.vouchers to authenticated;
drop policy if exists orderbuddy_vouchers_access on public.vouchers;
create policy orderbuddy_vouchers_access on public.vouchers
for all to authenticated
using (public.user_has_restaurant_access(restaurant_id))
with check (public.user_has_restaurant_access(restaurant_id));

create table if not exists public.voucher_events (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  event_type text not null,
  amount numeric(12,2) not null default 0,
  note text,
  created_by_email text,
  created_at timestamptz not null default now()
);
alter table public.voucher_events add column if not exists restaurant_id uuid;
alter table public.voucher_events add column if not exists voucher_id uuid;
alter table public.voucher_events add column if not exists event_type text;
alter table public.voucher_events add column if not exists amount numeric(12,2) default 0;
alter table public.voucher_events add column if not exists note text;
alter table public.voucher_events add column if not exists created_by_email text;
alter table public.voucher_events add column if not exists created_at timestamptz default now();
create index if not exists voucher_events_voucher_idx on public.voucher_events(voucher_id, created_at);
alter table public.voucher_events enable row level security;
grant select, insert, update, delete on public.voucher_events to authenticated;
drop policy if exists orderbuddy_voucher_events_access on public.voucher_events;
create policy orderbuddy_voucher_events_access on public.voucher_events
for all to authenticated
using (public.user_has_restaurant_access(restaurant_id))
with check (public.user_has_restaurant_access(restaurant_id));

-- Standard-Gutscheinverkauf an einem offenen Tisch/Auftrag.
-- In älteren OrderBuddy-Ständen existierte dieselbe Signatur mit anderem Rückgabetyp.
-- PostgreSQL kann den Rückgabetyp nicht per CREATE OR REPLACE ändern; daher gezielt neu anlegen.
drop function if exists public.create_orderbuddy_voucher(numeric,text,uuid);
create or replace function public.create_orderbuddy_voucher(
  p_value numeric,
  p_note text default null,
  p_session_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_restaurant_id uuid;
  v_session_status text;
  v_number bigint;
  v_code text;
  v_tz text;
  v_year text;
  v_row public.vouchers%rowtype;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  if p_value is null or p_value <= 0 then raise exception 'Gutscheinwert muss größer als 0 sein'; end if;
  if p_session_id is null then raise exception 'Für den Gutscheinverkauf muss ein offener Vorgang geöffnet sein'; end if;

  select restaurant_id,status into v_restaurant_id,v_session_status
  from public.table_sessions where id=p_session_id for update;
  if v_restaurant_id is null then raise exception 'Vorgang nicht gefunden'; end if;
  if v_session_status <> 'open' then raise exception 'Der Vorgang ist bereits abgeschlossen'; end if;
  if not public.user_has_restaurant_access(v_restaurant_id) then raise exception 'Keine Berechtigung'; end if;

  perform pg_advisory_xact_lock(hashtext(v_restaurant_id::text));
  select coalesce(timezone,'Europe/Berlin') into v_tz from public.restaurants where id=v_restaurant_id;
  v_year := to_char(now() at time zone coalesce(v_tz,'Europe/Berlin'),'YYYY');
  select coalesce(max((substring(voucher_number from ('^G-'||v_year||'-([0-9]+)$')))::bigint),0)+1
    into v_number from public.vouchers
    where restaurant_id=v_restaurant_id and voucher_number ~ ('^G-'||v_year||'-[0-9]+$');
  v_code := 'G-'||v_year||'-'||lpad(v_number::text,3,'0');

  insert into public.vouchers(restaurant_id,session_id,event_id,voucher_number,original_value,remaining_value,status,note,issued_at,created_by_email)
  values(v_restaurant_id,p_session_id,null,v_code,round(p_value,2),round(p_value,2),'active',nullif(trim(coalesce(p_note,'')),''),now(),v_email)
  returning * into v_row;

  insert into public.voucher_events(restaurant_id,voucher_id,event_type,amount,note,created_by_email)
  values(v_restaurant_id,v_row.id,'issued',v_row.original_value,v_row.note,v_email);

  return to_jsonb(v_row);
end;
$$;
revoke all on function public.create_orderbuddy_voucher(numeric,text,uuid) from public, anon;
grant execute on function public.create_orderbuddy_voucher(numeric,text,uuid) to authenticated;

-- Gutscheinverkauf innerhalb einer übergebenen Veranstaltung.
create or replace function public.create_orderbuddy_event_voucher(
  p_event_id uuid,
  p_value numeric,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
  v_number bigint;
  v_code text;
  v_tz text;
  v_year text;
  v_row public.vouchers%rowtype;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  if p_value is null or p_value <= 0 then raise exception 'Gutscheinwert muss größer als 0 sein'; end if;
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if v_event.status <> 'open' or v_event.slot_number is null then raise exception 'Veranstaltung ist nicht im Service geöffnet'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;

  perform pg_advisory_xact_lock(hashtext(v_event.restaurant_id::text));
  select coalesce(timezone,'Europe/Berlin') into v_tz from public.restaurants where id=v_event.restaurant_id;
  v_year := to_char(now() at time zone coalesce(v_tz,'Europe/Berlin'),'YYYY');
  select coalesce(max((substring(voucher_number from ('^G-'||v_year||'-([0-9]+)$')))::bigint),0)+1
    into v_number from public.vouchers
    where restaurant_id=v_event.restaurant_id and voucher_number ~ ('^G-'||v_year||'-[0-9]+$');
  v_code := 'G-'||v_year||'-'||lpad(v_number::text,3,'0');

  insert into public.vouchers(restaurant_id,session_id,event_id,voucher_number,original_value,remaining_value,status,note,issued_at,created_by_email)
  values(v_event.restaurant_id,null,p_event_id,v_code,round(p_value,2),round(p_value,2),'active',nullif(trim(coalesce(p_note,'')),''),now(),v_email)
  returning * into v_row;

  insert into public.voucher_events(restaurant_id,voucher_id,event_type,amount,note,created_by_email)
  values(v_event.restaurant_id,v_row.id,'issued',v_row.original_value,v_row.note,v_email);

  return to_jsonb(v_row);
end;
$$;
revoke all on function public.create_orderbuddy_event_voucher(uuid,numeric,text) from public, anon;
grant execute on function public.create_orderbuddy_event_voucher(uuid,numeric,text) to authenticated;

create or replace function public.redeem_orderbuddy_voucher(
  p_voucher_id uuid,
  p_amount numeric,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v public.vouchers%rowtype;
  v_new numeric(12,2);
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  select * into v from public.vouchers where id=p_voucher_id for update;
  if not found then raise exception 'Gutschein nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v.status not in ('active','partially_redeemed') or coalesce(v.remaining_value,0)<=0 then raise exception 'Gutschein ist nicht mehr gültig'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Einlösungsbetrag muss größer als 0 sein'; end if;
  if p_amount>v.remaining_value+0.004 then raise exception 'Einlösungsbetrag überschreitet den Restwert'; end if;

  v_new := round(greatest(0,v.remaining_value-p_amount),2);
  update public.vouchers
    set remaining_value=v_new,
        status=case when v_new<=0.004 then 'redeemed' else 'partially_redeemed' end
  where id=v.id;
  insert into public.voucher_events(restaurant_id,voucher_id,event_type,amount,note,created_by_email)
  values(v.restaurant_id,v.id,'redeemed',round(p_amount,2),nullif(trim(coalesce(p_note,'')),''),v_email);

  return jsonb_build_object('ok',true,'voucher_id',v.id,'remaining_value',v_new);
end;
$$;
revoke all on function public.redeem_orderbuddy_voucher(uuid,numeric,text) from public, anon;
grant execute on function public.redeem_orderbuddy_voucher(uuid,numeric,text) to authenticated;

create or replace function public.remove_or_void_orderbuddy_voucher(p_voucher_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v public.vouchers%rowtype;
  v_parent_open boolean := false;
  v_latest bigint;
  v_this bigint;
  v_released boolean := false;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  select * into v from public.vouchers where id=p_voucher_id for update;
  if not found then raise exception 'Gutschein nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v.restaurant_id) then raise exception 'Keine Berechtigung'; end if;

  if v.session_id is not null then
    select status='open' into v_parent_open from public.table_sessions where id=v.session_id;
  elsif v.event_id is not null then
    select status in ('draft','open') into v_parent_open from public.events where id=v.event_id;
  end if;

  select coalesce(max((substring(voucher_number from '([0-9]+)$'))::bigint),0)
    into v_latest from public.vouchers where restaurant_id=v.restaurant_id and status<>'void';
  v_this := coalesce((substring(v.voucher_number from '([0-9]+)$'))::bigint,0);

  if v_parent_open and v_this=v_latest and not exists(
    select 1 from public.voucher_events where voucher_id=v.id and event_type='redeemed'
  ) then
    delete from public.voucher_events where voucher_id=v.id;
    delete from public.vouchers where id=v.id;
    v_released := true;
  else
    update public.vouchers set status='void',remaining_value=0 where id=v.id;
    insert into public.voucher_events(restaurant_id,voucher_id,event_type,amount,note,created_by_email)
    values(v.restaurant_id,v.id,'voided',coalesce(v.remaining_value,0),'Gutschein storniert',v_email);
  end if;

  return jsonb_build_object(
    'ok',true,
    'voucher_number',v.voucher_number,
    'released_number',v_released,
    'session_status',case when v_parent_open then 'open' else 'closed' end
  );
end;
$$;
revoke all on function public.remove_or_void_orderbuddy_voucher(uuid) from public, anon;
grant execute on function public.remove_or_void_orderbuddy_voucher(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Abrechnung: Vorbereitung und Abschluss atomar über RPC
-- ---------------------------------------------------------------------------
create or replace function public.prepare_orderbuddy_bill_group(
  p_session_id uuid,
  p_label text,
  p_item_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_session public.table_sessions%rowtype;
  v_group_id uuid;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
  v_count integer;
begin
  select * into v_session from public.table_sessions where id=p_session_id for update;
  if not found then raise exception 'Vorgang nicht gefunden'; end if;
  if v_session.status<>'open' then raise exception 'Vorgang ist bereits abgeschlossen'; end if;
  if not public.user_has_restaurant_access(v_session.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if p_item_ids is null or cardinality(p_item_ids)=0 then raise exception 'Keine Position ausgewählt'; end if;

  select count(*) into v_count
  from public.order_items oi
  where oi.session_id=p_session_id and oi.id=any(p_item_ids) and coalesce(oi.cancelled,false)=false
    and not exists(
      select 1 from public.bill_group_items bgi
      join public.bill_groups bg on bg.id=bgi.bill_group_id
      where bgi.order_item_id=oi.id and bg.status<>'cancelled'
    );
  if v_count<>cardinality(p_item_ids) then raise exception 'Mindestens eine Position ist nicht mehr verfügbar oder bereits abgerechnet'; end if;

  insert into public.bill_groups(restaurant_id,table_id,session_id,label,status,prepared_at,prepared_by_email)
  values(v_session.restaurant_id,v_session.table_id,v_session.id,coalesce(nullif(trim(p_label),''),'Gesamt'),'handed_to_register',now(),v_email)
  returning id into v_group_id;

  insert into public.bill_group_items(bill_group_id,order_item_id,quantity)
  select v_group_id,oi.id,oi.quantity from public.order_items oi where oi.id=any(p_item_ids);

  return v_group_id;
end;
$$;
revoke all on function public.prepare_orderbuddy_bill_group(uuid,text,uuid[]) from public, anon;
grant execute on function public.prepare_orderbuddy_bill_group(uuid,text,uuid[]) to authenticated;

create or replace function public.complete_orderbuddy_bill_group(
  p_bill_group_id uuid,
  p_total numeric,
  p_payments jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_group public.bill_groups%rowtype;
  v_session public.table_sessions%rowtype;
  v_goods numeric(12,2);
  v_paid numeric(12,2);
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  select * into v_group from public.bill_groups where id=p_bill_group_id for update;
  if not found then raise exception 'Abrechnungsgruppe nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_group.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_group.status='completed' then return jsonb_build_object('ok',true,'already_completed',true); end if;
  if v_group.status='cancelled' then raise exception 'Abrechnungsgruppe wurde verworfen'; end if;

  select * into v_session from public.table_sessions where id=v_group.session_id;
  select round(coalesce(sum(oi.unit_price*bgi.quantity),0),2)
    into v_goods
  from public.bill_group_items bgi join public.order_items oi on oi.id=bgi.order_item_id
  where bgi.bill_group_id=v_group.id;

  if p_total is null or p_total<v_goods-0.005 then raise exception 'Abrechnungssumme ist kleiner als die Positionen'; end if;
  if coalesce(v_session.order_type,'')<>'Lieferung' and abs(p_total-v_goods)>0.005 then raise exception 'Abrechnungssumme stimmt nicht mit den Positionen überein'; end if;
  if coalesce(v_session.order_type,'')='Lieferung' and p_total>v_goods+coalesce(v_session.delivery_fee,0)+0.005 then raise exception 'Abrechnungssumme ist zu hoch'; end if;
  if jsonb_typeof(p_payments)<>'array' or jsonb_array_length(p_payments)=0 then raise exception 'Mindestens eine Zahlungsart erforderlich'; end if;
  if exists(select 1 from jsonb_array_elements(p_payments) x where (x->>'payment_method') not in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other') or coalesce((x->>'amount')::numeric,0)<=0) then raise exception 'Ungültige Zahlungsart oder Betrag'; end if;
  select round(coalesce(sum((x->>'amount')::numeric),0),2) into v_paid from jsonb_array_elements(p_payments) x;
  if abs(v_paid-p_total)>0.005 then raise exception 'Zahlungssumme stimmt nicht'; end if;

  delete from public.bill_group_payments where bill_group_id=v_group.id;
  insert into public.bill_group_payments(restaurant_id,bill_group_id,payment_method,amount,created_by_email)
  select v_group.restaurant_id,v_group.id,x->>'payment_method',round((x->>'amount')::numeric,2),v_email
  from jsonb_array_elements(p_payments) x;

  update public.bill_groups set status='completed',completed_at=now(),completed_by_email=v_email where id=v_group.id;
  return jsonb_build_object('ok',true,'bill_group_id',v_group.id,'gross',p_total);
end;
$$;
revoke all on function public.complete_orderbuddy_bill_group(uuid,numeric,jsonb) from public, anon;
grant execute on function public.complete_orderbuddy_bill_group(uuid,numeric,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Veranstaltungen: Alles-erledigt + Gutschein in Abschlussbetrag
-- ---------------------------------------------------------------------------
create or replace function public.mark_orderbuddy_event_all_done(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_event.status<>'open' or v_event.slot_number is null then raise exception 'Veranstaltung ist nicht im Service geöffnet'; end if;

  update public.events
    set package_status=case when mode in ('package','package_and_alacarte') then 'done' else package_status end,
        ready_for_checkout=false
  where id=p_event_id;
  update public.event_items set status='done' where event_id=p_event_id and status<>'done';
  return jsonb_build_object('ok',true,'event_id',p_event_id);
end;
$$;
revoke all on function public.mark_orderbuddy_event_all_done(uuid) from public, anon;
grant execute on function public.mark_orderbuddy_event_all_done(uuid) to authenticated;


-- Abrechnung und finaler Abschluss sind bewusst getrennt, analog zu Tischen.
create or replace function public.save_orderbuddy_event_payments(p_event_id uuid, p_payments jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
  v_expected numeric(12,2);
  v_paid numeric(12,2);
  v_first_method text;
  v_count integer;
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_event.status<>'open' or v_event.slot_number is null then raise exception 'Veranstaltung wurde noch nicht an den Service übergeben'; end if;
  if not v_event.ready_for_checkout then raise exception 'Veranstaltung ist noch nicht bereit zum Abschluss'; end if;
  if v_event.mode in ('package','package_and_alacarte') and v_event.package_status<>'done' then raise exception 'Veranstaltungspaket ist noch nicht erledigt'; end if;
  if exists(select 1 from public.event_items where event_id=p_event_id and status<>'done') then raise exception 'Nicht alle Positionen sind erledigt'; end if;

  select round(
    (case when v_event.mode in ('package','package_and_alacarte') then v_event.package_price_per_person*v_event.guest_count else 0 end)
    + coalesce((select sum(quantity*unit_price) from public.event_items where event_id=p_event_id),0)
    + coalesce((select sum(original_value) from public.vouchers where event_id=p_event_id and status<>'void'),0)
  ,2) into v_expected;

  if jsonb_typeof(p_payments)<>'array' or jsonb_array_length(p_payments)=0 then raise exception 'Mindestens eine Zahlungsart erforderlich'; end if;
  if exists(select 1 from jsonb_array_elements(p_payments) x where (x->>'payment_method') not in ('cash','girocard','credit_card','apple_pay','google_pay','voucher','bank_transfer','online','other') or coalesce((x->>'amount')::numeric,0)<=0) then raise exception 'Ungültige Zahlungsart oder Betrag'; end if;
  select round(coalesce(sum((x->>'amount')::numeric),0),2),count(*),min(x->>'payment_method') into v_paid,v_count,v_first_method from jsonb_array_elements(p_payments) x;
  if abs(v_paid-v_expected)>0.005 then raise exception 'Zahlungssumme stimmt nicht mit Veranstaltungssumme überein'; end if;

  delete from public.event_payments where event_id=p_event_id;
  insert into public.event_payments(event_id,restaurant_id,payment_method,amount,created_by_email)
  select p_event_id,v_event.restaurant_id,x->>'payment_method',round((x->>'amount')::numeric,2),v_email from jsonb_array_elements(p_payments) x;

  update public.events set payment_method=case when v_count=1 then v_first_method else 'other' end where id=p_event_id;
  return jsonb_build_object('ok',true,'event_id',p_event_id,'gross',v_expected,'payment_saved',true);
end;
$$;
revoke all on function public.save_orderbuddy_event_payments(uuid,jsonb) from public, anon;
grant execute on function public.save_orderbuddy_event_payments(uuid,jsonb) to authenticated;

-- Kompatibilitätsname aus V32.2: speichert jetzt ebenfalls nur die Abrechnung.
create or replace function public.close_orderbuddy_event_with_payments(p_event_id uuid, p_payments jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  return public.save_orderbuddy_event_payments(p_event_id,p_payments);
end;
$$;
revoke all on function public.close_orderbuddy_event_with_payments(uuid,jsonb) from public, anon;
grant execute on function public.close_orderbuddy_event_with_payments(uuid,jsonb) to authenticated;

create or replace function public.close_orderbuddy_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_event public.events%rowtype;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
  v_expected numeric(12,2);
  v_paid numeric(12,2);
begin
  select * into v_event from public.events where id=p_event_id for update;
  if not found then raise exception 'Veranstaltung nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v_event.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v_event.status='closed' then return jsonb_build_object('ok',true,'already_closed',true); end if;
  if v_event.status<>'open' or v_event.slot_number is null then raise exception 'Veranstaltung ist nicht im Service geöffnet'; end if;
  if not v_event.ready_for_checkout then raise exception 'Veranstaltung ist noch nicht bereit zum Abschluss'; end if;
  if v_event.mode in ('package','package_and_alacarte') and v_event.package_status<>'done' then raise exception 'Veranstaltungspaket ist noch nicht erledigt'; end if;
  if exists(select 1 from public.event_items where event_id=p_event_id and status<>'done') then raise exception 'Nicht alle Positionen sind erledigt'; end if;

  select round(
    (case when v_event.mode in ('package','package_and_alacarte') then v_event.package_price_per_person*v_event.guest_count else 0 end)
    + coalesce((select sum(quantity*unit_price) from public.event_items where event_id=p_event_id),0)
    + coalesce((select sum(original_value) from public.vouchers where event_id=p_event_id and status<>'void'),0)
  ,2) into v_expected;
  select round(coalesce(sum(amount),0),2) into v_paid from public.event_payments where event_id=p_event_id;
  if abs(v_paid-v_expected)>0.005 then raise exception 'Bitte zuerst die vollständige Abrechnung speichern'; end if;

  update public.events set status='closed',closed_at=now(),closed_by_email=v_email where id=p_event_id;
  return jsonb_build_object('ok',true,'event_id',p_event_id,'gross',v_expected);
end;
$$;
revoke all on function public.close_orderbuddy_event(uuid) from public, anon;
grant execute on function public.close_orderbuddy_event(uuid) to authenticated;

-- Finaler Tisch-/Auftragsabschluss als atomare DB-Operation.
create or replace function public.close_orderbuddy_table_session(
  p_session_id uuid,
  p_delivery_fee numeric default null,
  p_closed_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v public.table_sessions%rowtype;
  v_email text := coalesce((select auth.jwt()) ->> 'email','');
begin
  select * into v from public.table_sessions where id=p_session_id for update;
  if not found then raise exception 'Vorgang nicht gefunden'; end if;
  if not public.user_has_restaurant_access(v.restaurant_id) then raise exception 'Keine Berechtigung'; end if;
  if v.status='closed' then return jsonb_build_object('ok',true,'already_closed',true); end if;
  if v.status<>'open' then raise exception 'Vorgang ist nicht offen'; end if;
  if not coalesce(v.ready_for_checkout,false) then raise exception 'Bitte den Vorgang zuerst bewusst auf Grün setzen'; end if;
  if exists(select 1 from public.bill_groups where session_id=p_session_id and status not in ('completed','cancelled')) then raise exception 'Es gibt noch eine nicht abgeschlossene Abrechnung'; end if;
  if exists(
    select 1 from public.order_items oi
    where oi.session_id=p_session_id and coalesce(oi.cancelled,false)=false
      and not exists(
        select 1 from public.bill_group_items bgi
        join public.bill_groups bg on bg.id=bgi.bill_group_id and bg.status='completed'
        where bgi.order_item_id=oi.id
      )
  ) then raise exception 'Es gibt noch nicht abgerechnete Positionen'; end if;

  update public.table_sessions
     set status='closed',ready_for_checkout=false,restore_ready_on_revert=false,reopened_from_checkout_at=null,
         closed_at=coalesce(p_closed_at,now()),closed_by_email=v_email,
         delivery_fee=coalesce(p_delivery_fee,delivery_fee)
   where id=p_session_id;
  return jsonb_build_object('ok',true,'session_id',p_session_id,'table_id',v.table_id);
end;
$$;
revoke all on function public.close_orderbuddy_table_session(uuid,numeric,timestamptz) from public, anon;
grant execute on function public.close_orderbuddy_table_session(uuid,numeric,timestamptz) to authenticated;

-- Eigener Druckverlauf für Veranstaltungen; unabhängig von print_jobs der Tische.
create table if not exists public.event_print_jobs(
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  destination text not null,
  document_type text not null,
  snapshot jsonb,
  is_reprint boolean not null default false,
  reprint_of uuid null references public.event_print_jobs(id) on delete set null,
  requested_by_email text,
  created_at timestamptz not null default now()
);
create index if not exists event_print_jobs_event_idx on public.event_print_jobs(event_id,created_at desc);
alter table public.event_print_jobs enable row level security;
grant select,insert,update,delete on public.event_print_jobs to authenticated;
drop policy if exists orderbuddy_event_print_jobs_access on public.event_print_jobs;
create policy orderbuddy_event_print_jobs_access on public.event_print_jobs
for all to authenticated
using (public.user_has_restaurant_access(restaurant_id))
with check (public.user_has_restaurant_access(restaurant_id));



-- ---------------------------------------------------------------------------
-- V32.6: Archiv-Löschen für abgeschlossene Vorgänge / Veranstaltungen
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

create or replace function public.delete_orderbuddy_closed_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_restaurant_id uuid;
  v_status text;
  v_closed_at timestamptz;
  v_closed_date date;
begin
  select restaurant_id,status,closed_at
    into v_restaurant_id,v_status,v_closed_at
  from public.events
  where id=p_event_id;

  if v_restaurant_id is null then
    raise exception 'Veranstaltung nicht gefunden.';
  end if;
  if v_status <> 'closed' then
    raise exception 'Nur abgeschlossene Veranstaltungen können gelöscht werden.';
  end if;
  if not public.is_orderbuddy_admin(v_restaurant_id) then
    raise exception 'Keine Berechtigung. Nur Owner/Admin.';
  end if;

  v_closed_date := (v_closed_at at time zone 'Europe/Berlin')::date;

  -- Abhängige Datensätze sind per FK auf ON DELETE CASCADE ausgelegt.
  delete from public.events where id=p_event_id;

  -- Bereits gesetzte Export-Markierungen des Abschluss-Tages zurücksetzen.
  if v_closed_date is not null then
    delete from public.day_exports
      where restaurant_id=v_restaurant_id and business_date=v_closed_date;
  end if;

  return jsonb_build_object('ok',true,'closed_date',v_closed_date);
end;
$$;
revoke all on function public.delete_orderbuddy_closed_event(uuid) from public, anon;
grant execute on function public.delete_orderbuddy_closed_event(uuid) to authenticated;



-- ---------------------------------------------------------------------------
-- V32.7: Tagesabschluss über alle 5 Bereiche löschen
-- Terrasse / Innenraum / Lieferung / Abholung = table_sessions
-- Veranstaltungen = events
-- Maßgeblich ist immer der tatsächliche Abschlusszeitpunkt closed_at.
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_orderbuddy_day_v2(
  p_restaurant_id uuid,
  p_business_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamptz;
  v_end timestamptz;
  v_sessions integer := 0;
  v_events integer := 0;
begin
  if not public.is_orderbuddy_admin(p_restaurant_id) then
    raise exception 'Keine Berechtigung. Nur Owner/Admin.';
  end if;

  if exists(select 1 from public.table_sessions where restaurant_id=p_restaurant_id and status='open')
     or exists(select 1 from public.events where restaurant_id=p_restaurant_id and status='open') then
    raise exception 'Es gibt noch offene Vorgänge. Tag kann nicht endgültig gelöscht werden.';
  end if;

  v_start := p_business_date::timestamp at time zone 'Europe/Berlin';
  v_end := (p_business_date + 1)::timestamp at time zone 'Europe/Berlin';

  delete from public.table_sessions
   where restaurant_id=p_restaurant_id
     and status='closed'
     and closed_at >= v_start
     and closed_at < v_end;
  get diagnostics v_sessions = row_count;

  delete from public.events
   where restaurant_id=p_restaurant_id
     and status='closed'
     and closed_at >= v_start
     and closed_at < v_end;
  get diagnostics v_events = row_count;

  delete from public.day_exports
   where restaurant_id=p_restaurant_id
     and business_date=p_business_date;

  return jsonb_build_object(
    'ok', true,
    'sessions', v_sessions,
    'events', v_events,
    'total', v_sessions + v_events
  );
end;
$$;
revoke all on function public.admin_delete_orderbuddy_day_v2(uuid,date) from public, anon;
grant execute on function public.admin_delete_orderbuddy_day_v2(uuid,date) to authenticated;

commit;
