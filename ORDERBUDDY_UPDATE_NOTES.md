# OrderBuddy – konsolidierter Stand V30

Dieser Stand wurde ausschließlich aus dem zuletzt bereitgestellten aktuellen Projekt aufgebaut. Er bündelt die bisherigen Fixes und die zuletzt gesammelten Anforderungen in einer gemeinsamen Basis.

## Bedienung & PWA
- Passwort kann im Login per Augen-Symbol angezeigt/verborgen werden.
- Sichtbarer Punkt **Aktualisieren** im App-Kopf sowie unter Einstellungen.
- Service Worker auf V30 mit Network-first-Update, Cache-Bereinigung und `SKIP_WAITING`.
- App-Name bleibt **OrderBuddy** auf iPhone/iPad/Mac.

## Tisch-, Liefer- und Abholstatus
- Leere Tische/Auftragsplätze bleiben frei/weiß.
- Terrasse/Innenraum: Gelb offen, Orange in Arbeit, Blau fertig/Service, Grün bewusst „bereit zum Abschluss“.
- Lieferung: Gelb Auftrag angenommen, Orange in Zubereitung, Blau Essen fertig/wartet auf Fahrer, Grün Fahrer unterwegs.
- Abholung: Gelb Auftrag angenommen, Orange in Zubereitung, Blau Essen fertig/wartet auf Abholung, Grün Kunde da/Übergabe läuft.
- Nachbestellungen setzen einen grünen Vorgang zurück; wird die Nachbestellung vollständig zurückgenommen, kann der vorherige grüne Zustand wiederhergestellt werden.
- Fehlende Statusfelder aus älteren Datenbankständen werden durch das konsolidierte SQL ergänzt.

## Historische Bestellungen
- Neuer Chefbereich **Bestellungen nachtragen**.
- Datum kann in der Vergangenheit gewählt werden.
- Uhrzeit ist optional; leer bedeutet **00:00 Uhr**.
- Historisches Datum/Uhrzeit werden für Sitzung, Positionen, Abschluss und Bon-Kontext verwendet.

## Vorspeisen & Bons
- „Vorspeise vorab / zusammen mit Hauptgang“ nur für Terrasse und Innenraum.
- Bei Lieferung und Abholung wird diese Frage nicht gestellt.
- Bezeichnungen auf Bons:
  - `Tisch T-1`
  - `Tisch I-1`
  - `Lieferung L-1`
  - `Abholung A-1`
- Küchenbons gruppieren Vorab-Vorspeisen zuerst mit klarer Trennung.
- Bon-Logo mit abgerundeten Ecken.
- Thermobons sind als fortlaufende Einzelseite ausgelegt.

## Lieferung
- Lieferzonen mit PLZ, Ort, Lieferpreis, Aktiv/Inaktiv und **Mindestbestellwert für kostenfreie Lieferung**.
- Erreicht der Brutto-Warenwert die Zonengrenze, werden die Lieferkosten automatisch 0,00 €.
- Lieferkosten werden für 7 % / 19 % proportional nach den jeweiligen **Nettowarenwerten** der Waren aufgeteilt.
- Feste Straßenverzeichnisse bleiben exakt über **PLZ + Ort** getrennt; Straße und Hausnummer sind separate Felder.

## Service-Signal
- Optionaler Signalton auf angemeldeten Servicegeräten, sobald eine Küchenposition den Status **Erledigt** erreicht.
- Unter Einstellungen ein-/ausschaltbar.

## Manuelle Buchungen & DATEV
- Bei Kostenbuchungen ohne angegebenes Konto wird automatisch **1590 – Durchlaufender Posten** verwendet.
- Bestehende vier DATEV-Varianten bleiben erhalten:
  1. Einzelpositionen automatisch
  2. Tagessummen automatisch
  3. Einzelpositionen komplett inkl. manueller Buchungen
  4. Tagessummen komplett inkl. manueller Buchungen
- Fünfte Monats-CSV bleibt für Nicht-Bar-Zahlungen.
- Lieferkosten werden in den steuerlichen Exporten entsprechend 7 % / 19 % aufgeteilt.

## Monats-ZIP mit Belegen
- Neuer Export **ZIP · alle CSV + Bon-PDFs**.
- Enthält die vier DATEV-Dateien, Nicht-Bar-CSV, Beleg-PDFs sowie `Belegzuordnung.csv`.
- Belege werden über das Belegfeld eindeutig den Buchungen zugeordnet.

## Veranstaltungen
- Neuer Chefbereich **Veranstaltungen**.
- Varianten:
  - nur À-la-carte
  - Pauschale pro Person
  - Pauschale + zusätzliche À-la-carte-Positionen
- Pauschale wahlweise:
  - **70 % Speisen / 30 % Getränke**
  - manuelle Bruttoaufteilung 7 % / 19 %
- Personenzahl und Preis pro Person werden berücksichtigt.
- Zusätzliche À-la-carte-Speisen/Getränke können hinzugefügt und für Küche/Bar gedruckt werden.
- Veranstaltungen fließen in Monats-DATEV, Nicht-Bar-Auswertung sowie Tages-/Monats-Steuerzusammenfassungen ein.

## Datenbank
Vor dem Deployment einmal `SUPABASE_ORDERBUDDY_CONSOLIDATED_V30.sql` im Supabase SQL Editor ausführen. Das Skript ist wiederholt ausführbar und ergänzt nur die benötigten Felder/Tabellen.

## Empfohlener Funktionstest nach dem Deployment
1. Login + Passwort anzeigen.
2. Freien Tisch öffnen, Position hinzufügen, alle vier Statusstufen prüfen.
3. Nachbestellung nach Grün hinzufügen und wieder stornieren.
4. Lieferung/Abholung leer öffnen: muss frei bleiben; danach Auftrag und Statusfolge testen.
5. Lieferzone mit Mindestbestellwert unter/über Schwelle testen.
6. Lieferbon mit Speisen + Getränk prüfen: Lieferkosten-Steueraufteilung kontrollieren.
7. Historische Bestellung mit leerer Uhrzeit erfassen und auf 00:00 prüfen.
8. Veranstaltung mit 70/30 sowie manuellem Split anlegen; À-la-carte ergänzen.
9. Manuelle Kostenbuchung ohne Konto: 1590 prüfen.
10. Monats-ZIP erzeugen und CSV-/PDF-Zuordnung prüfen.
11. App-Aktualisierung auf iPhone und Mac testen.
