-- OrderBuddy V27 Reparatur: fehlende Statusspalten ergänzen.
alter table public.table_sessions
  add column if not exists restore_ready_on_revert boolean not null default false,
  add column if not exists reopened_from_checkout_at timestamptz null;

-- PostgREST/Supabase erkennt Schemaänderungen normalerweise automatisch.
-- Falls der Browser noch eine alte Schema-Cache-Meldung zeigt, Seite einmal neu laden.
