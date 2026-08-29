-- OrderBuddy V17: PLZ je Lieferzone
alter table public.delivery_zones
  add column if not exists postal_code text;

-- Nur fünfstellige deutsche PLZ oder leer/null zulassen.
alter table public.delivery_zones
  drop constraint if exists delivery_zones_postal_code_check;
alter table public.delivery_zones
  add constraint delivery_zones_postal_code_check
  check (postal_code is null or postal_code = '' or postal_code ~ '^[0-9]{5}$');

comment on column public.delivery_zones.postal_code is
  'Deutsche PLZ der Lieferzone; dient zur eindeutigen Ortszuordnung und für Adressvorschläge.';
