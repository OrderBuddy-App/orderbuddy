-- OrderBuddy: interne Supabase-RPC-Namen von NOVA auf OrderBuddy umstellen
-- Einmal im Supabase SQL Editor ausführen, danach Frontend neu deployen.
-- Die Migration benennt nur Funktionen um; Tabellen und Daten werden nicht verändert.

DO $$
DECLARE
  r record;
  new_name text;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name,
           p.proname AS old_name,
           p.oid,
           pg_get_function_identity_arguments(p.oid) AS identity_args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname ILIKE '%nova%'
  LOOP
    new_name := replace(r.old_name, 'nova', 'orderbuddy');

    IF new_name = r.old_name THEN
      new_name := replace(r.old_name, 'NOVA', 'ORDERBUDDY');
    END IF;

    IF EXISTS (
      SELECT 1
      FROM pg_proc p2
      JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
      WHERE n2.nspname = r.schema_name
        AND p2.proname = new_name
        AND pg_get_function_identity_arguments(p2.oid) = r.identity_args
    ) THEN
      RAISE NOTICE 'Übersprungen: %.%(%) -> Ziel existiert bereits: %', r.schema_name, r.old_name, r.identity_args, new_name;
    ELSE
      EXECUTE format(
        'ALTER FUNCTION %I.%I(%s) RENAME TO %I',
        r.schema_name,
        r.old_name,
        r.identity_args,
        new_name
      );
      RAISE NOTICE 'Umbenannt: %.% -> %', r.schema_name, r.old_name, new_name;
    END IF;
  END LOOP;
END $$;

-- Erwartete OrderBuddy-RPCs prüfen
SELECT p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'current_orderbuddy_role',
    'remove_or_void_orderbuddy_voucher',
    'create_orderbuddy_voucher',
    'redeem_orderbuddy_voucher',
    'admin_delete_orderbuddy_day'
  )
ORDER BY p.proname;

-- Kontrolle: danach sollte hier 0 Zeilen erscheinen.
SELECT p.proname AS remaining_nova_function
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname ILIKE '%nova%';
