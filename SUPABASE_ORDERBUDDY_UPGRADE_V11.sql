-- OrderBuddy V11: merkt sich, ob ein grüner Tisch nur wegen einer Nachbestellung zurückgestuft wurde.
alter table public.table_sessions
  add column if not exists restore_ready_on_revert boolean not null default false;
