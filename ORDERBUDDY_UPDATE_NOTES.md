# OrderBuddy – konsolidierter Stand V31.3

Dieser Stand wurde ausschließlich aus der zuletzt hochgeladenen vollständigen Projektversion aufgebaut. Alte ZIPs und alte Einzelpatches wurden nicht als Basis verwendet.

## Zentral korrigiert
- Tages-/Monatslogik: fehlerhafte rekursive Summenfunktion entfernt.
- Abschluss: Ein Vorgang kann erst nach dem bewussten grünen Status endgültig abgeschlossen werden.
- Lieferung: Der tatsächlich gültige Lieferpreis wird beim Abschluss festgeschrieben; bei erreichtem Mindestbestellwert also 0,00 €.
- Nachträgliche Erfassung: Abschlusszeit und Nachbestell-Markierung verwenden das historische Datum/die historische Uhrzeit in der Restaurant-Zeitzone.
- Service-Ton: nur auf angemeldeten Servicegeräten, nicht im Chef/Admin-Zugang.
- Straßenverzeichnis: nicht mehr fest in der Kernlogik; die Listen werden je Lieferzone aus Supabase geladen. Polle/Brevörde bleiben über exakte PLZ+Ort-Zuordnung getrennt.
- PWA/Realtime-Version auf V31.3 angehoben.

## Weiter enthalten
- Terrasse / Innenraum / Lieferung / Abholung mit der vereinbarten Statuslogik.
- Nachbestellung nach Grün inklusive automatischer Rückkehr zu Grün, wenn die neue Position vollständig storniert wird.
- Küchen-/Bar-/Fahrer-/Abholbons und Folgebon-Logik.
- Vorspeisen-Gangwahl nur für Terrasse/Innenraum.
- Lieferzonen mit Lieferpreis, Aktiv/Inaktiv und Mindestbestellwert für kostenlose Lieferung.
- Proportionale Aufteilung von Lieferkosten auf 7 % / 19 % nach Nettowarenwerten.
- Mischzahlungen und Bargeldsaldo nur aus echten Bargeldbewegungen; Bar-Veranstaltungen und als Bar geführte Gutscheinverkäufe sind enthalten.
- Fallback 1590 für Kostenbuchungen ohne eingegebenes Konto.
- Vier DATEV-Varianten plus Nicht-Bar-Monatsdatei.
- Monats-ZIP mit CSV-Dateien, PDF-Belegen und Belegzuordnung.
- Abgeschlossene Bons: anzeigen, nachdrucken, PDF, einzeln löschen (Owner/Admin).
- Historische Bestellungen mit optionaler Uhrzeit; leer = 00:00 Uhr.
- Veranstaltungen: À-la-carte, Pauschale, Kombination, 70/30 oder manuelle Aufteilung.
- Passwort-Auge und eigener Aktualisieren-Button.

## Supabase
Vor dem Deployment einmal `SUPABASE_ORDERBUDDY_CONSOLIDATED_V31.sql` im SQL Editor ausführen. Das Skript ist für wiederholtes Ausführen ausgelegt und enthält die für diesen Stand benötigten Ergänzungen in einer Datei.

## Empfohlene Testreihenfolge
1. SQL V31.3 ausführen.
2. GitHub-Inhalt durch diesen vollständigen Stand ersetzen und `main` deployen lassen.
3. OrderBuddy über „Aktualisieren“ neu laden.
4. Terrasse/Innenraum: Gelb → Orange → Blau → bewusst Grün → Abschluss.
5. Nach Grün neue Position hinzufügen; danach einmal erledigen und einmal vollständig stornieren.
6. Lieferung unter/über Mindestbestellwert testen und anschließend Monats-/Tageswerte prüfen.
7. Polle und Brevörde getrennt testen: leeres Straßenfeld muss sofort die jeweilige vollständige Liste öffnen.
8. Historische Bestellung mit leerer Uhrzeit testen (00:00).
9. Service-Ton auf einem Servicegerät testen; Chef/Admin darf nicht mitklingeln.
10. Monats-ZIP öffnen und CSV/Belegzuordnung prüfen.


## V31.3 – Korrektur Lieferung/Abholung
- L-/A-Plätze ohne aktive Position werden unabhängig von einem alten ready_for_checkout-Flag immer als frei dargestellt.
- Beim Storno der letzten aktiven Position werden Grün-/Restore-Marker sofort gelöscht.
- Noch offene, nicht abgeschlossene Bill-Gruppen werden bei einem vollständig stornierten L-/A-Auftrag verworfen.
- Für V31.3 ist keine zusätzliche Supabase-SQL-Änderung erforderlich.
