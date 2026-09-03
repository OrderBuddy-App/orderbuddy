# OrderBuddy V34.0 – sauberer Testreset + Veranstaltungspauschale

Basis: ausschließlich die zuletzt hochgeladene `orderbuddy-main.zip` / V33-Basis.

## Neu
- Einmaliger Testdaten-Reset beim Ausführen von `SUPABASE_ORDERBUDDY_CONSOLIDATED_V34.sql`.
- Erhalten bleiben Restaurant-Konfiguration, Benutzer, Speisekarte, Bereiche/Tische, Lieferzonen/Straßen und Einstellungen.
- Gelöscht werden Vorgangs-/Testdaten: Bestellungen, Abrechnungen, Veranstaltungen, Gutscheine, manuelle Buchungen sowie Druck-/Exporthistorien.
- Reset ist über `private.orderbuddy_migration_flags` gegen versehentliches erneutes Löschen abgesichert.
- Begriff überall: Begriff überall auf `Veranstaltungspauschale` vereinheitlicht.
- Veranstaltungen können nach Personen getrennt abgerechnet werden: z. B. 24× Pauschale → 1× bezahlt → 23× offen.
- Bei einer Teilabrechnung können offene À-la-carte-Positionen und Gutscheinpositionen mit ausgewählt werden.
- Mischzahlungen sind je Teilabrechnung möglich.
- Bereits abgerechnete Event-Anteile erscheinen wie bei Tischen im Bereich `Abgeschlossen`.
- Abschluss der Veranstaltung ist erst möglich, wenn Pauschalen, À-la-carte-Positionen und Gutscheinpositionen vollständig abgerechnet sind.
- Aggregierte Event-Zahlungen bleiben die Quelle für DATEV/CSV/Monatsauswertungen.

## Dateien
- `index.html`
- `manifest.webmanifest`
- `service-worker.js`
- `vercel.json`
- `orderbuddy-logo.PNG`
- `SUPABASE_ORDERBUDDY_CONSOLIDATED_V34.sql`
- `ORDERBUDDY_UPDATE_NOTES.md`
