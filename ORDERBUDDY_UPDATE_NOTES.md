# OrderBuddy V32.5

Konsolidierte Auswertungs-Korrektur auf Basis von V32.4.

- Abgeschlossene Bons werden nach dem tatsächlichen Abschlusszeitpunkt (`closed_at`) gefiltert.
- Tagesauswertungen verwenden den tatsächlichen Abschlusszeitpunkt.
- Monats-/DATEV-Auswertungen verwenden den tatsächlichen Abschlusszeitpunkt.
- Fehlende Funktion `fetchMonthEvents()` ergänzt.
- Fehlende Funktion `fetchManualBookings()` ergänzt; Monatsbereich und manuelle Buchungen brechen nicht mehr ab.
- Nur endgültig abgeschlossene Tisch-/Auftragsvorgänge und Veranstaltungen werden automatisch ausgewertet.
- Endgültig gelöschte Vorgänge sind automatisch nicht mehr enthalten.
- Gutscheine werden erst berücksichtigt, wenn der zugehörige Tisch/Auftrag bzw. die Veranstaltung abgeschlossen ist.
- Kein neues Supabase-SQL erforderlich; V32.2-SQL bleibt Datenbankbasis.
