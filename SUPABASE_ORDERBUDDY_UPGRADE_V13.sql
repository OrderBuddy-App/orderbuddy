-- OrderBuddy V13: merkt den Beginn einer Nachbestellung nach "Bereit zum Abschluss".
-- Dadurch bleibt eine neue, noch nicht begonnene Position zunächst gelb und alte erledigte Positionen
-- färben den Tisch nicht sofort orange.
alter table public.table_sessions
  add column if not exists reopened_from_checkout_at timestamptz null;
