# OrderBuddy – nächster Umbau

Neu in dieser Version:

- Zahlungsart beim Abschluss einer Teilung auswählbar.
- Unterstützt Bar, Girocard/EC, Kreditkarte, Apple Pay, Google Pay, Gutschein, Überweisung, Online-Zahlung und Sonstiges.
- Mehrere Zahlungsarten pro Abschluss möglich (Teilzahlung / Mischzahlung).
- Vier DATEV-EXTF-Exporte:
  - Einzelpositionen automatisch
  - Tagessummen automatisch
  - Einzelpositionen komplett inkl. manueller Buchungen
  - Tagessummen komplett inkl. manueller Buchungen
- Zusätzliche Monats-CSV nur für Nicht-Bar-Zahlungen.
- Für bargeldlose Zahlungsarten können DATEV-Gegenkonten in den Einstellungen hinterlegt werden.
- Manuelle Buchungstexte bleiben standardmäßig leer.
- Neue manuelle Kategorie „Wechselgeld / Kassenstart“.
- Manuelle Bargeldbewegungen werden grün (+) bzw. rot (−) dargestellt.
- Laufender Bargeldsaldo enthält automatische Bar-Umsätze plus manuelle Bargeldbewegungen.
- Eine manuelle Ausgabe wird blockiert, wenn der rechnerische Bargeldsaldo dadurch negativ würde.
- Lieferung: beim Küchenlauf wird zusätzlich ein Fahrerbon erzeugt.
- Abholung: beim Küchenlauf wird zusätzlich ein Abhol-/Kassenbon erzeugt.
- Nachbestellungen verwenden einen eigenen Druckstatus, damit der Zusatzbon nur neue Positionen enthält.

## Vor dem Test

Einmal `SUPABASE_ORDERBUDDY_UPGRADE_V2.sql` im Supabase SQL Editor ausführen.
