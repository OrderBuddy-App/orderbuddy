# OrderBuddy V32.7

Konsolidierter Auswertungsumbau auf Basis von V32.6.

- Alle Auswertungen berücksichtigen einheitlich Terrasse, Innenraum, Lieferung, Abholung und Veranstaltungen.
- Übersicht: Veranstaltungen, Lieferkosten und alle fünf Bereiche in Anzahl/Umsatz/Top-Produkten/Kategorien/Service berücksichtigt.
- Neue Übersicht „Vorgänge nach Bereich“ für T / I / L / A / V.
- Bezeichnung „Abgeschlossene Vorgänge“ statt „Abgeschlossene Tische“.
- Tagesabschluss: V-Veranstaltungen werden in Anzahl, Liste, Summen, Detail-PDF und CSV berücksichtigt.
- Tages-/Monatszuordnung ausschließlich nach tatsächlichem Abschlusszeitpunkt `closed_at`.
- Monatsbereich zeigt jetzt Anzahl, Brutto, 7 %, 19 %, Gutscheinverkäufe und T/I/L/A/V-Aufteilung direkt an.
- DATEV-Einzelpositionen, DATEV-Tagessummen, Nicht-Bar-CSV und ZIP/Belege berücksichtigen alle fünf Bereiche.
- Fehlende `completedGroups()`-Funktion ergänzt.
- Monats-Belegzuordnung verwendet Abschlussdatum statt ursprünglichem Eröffnungs-/Veranstaltungsdatum.
- Monats-Tagesbelegberechnung nutzt gespeicherte Gruppenpositionen statt des aktuell geöffneten Tisches.
- Restaurantfilter bei Monats-/Gutschein-/Übersichtsabfragen vereinheitlicht.
- „Tag endgültig löschen“ löscht nach SQL-Update abgeschlossene T/I/L/A- und V-Vorgänge des Abschlussdatums gemeinsam.
- PWA-Cache V32.7.
