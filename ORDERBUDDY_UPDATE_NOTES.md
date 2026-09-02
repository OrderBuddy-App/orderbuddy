# OrderBuddy V32.2 – Abschluss, Gutscheinnummern und Veranstaltungen

Basis: aktueller V32.1-Stand, der ausschließlich aus der vom Nutzer am 03.09.2026 hochgeladenen `orderbuddy-main(1).zip` aufgebaut wurde.

- Gutscheinnummern jetzt jahresbezogen: `G-2026-001`, `G-2026-002`, ...; Zähler startet pro Restaurant und Jahr neu.
- Tisch-/Liefer-/Abholabschluss jetzt atomar über `close_orderbuddy_table_session`; Grün-Flags werden serverseitig zurückgesetzt.
- Veranstaltungen: Abrechnung und endgültiger Abschluss sind getrennt, analog zu normalen Tischen.
- Nach gespeicherter Abrechnung bleibt V-1 bis V-8 grün, bis bewusst `Veranstaltung abschließen` gewählt wird.
- Veranstaltungen erhalten einen Druckverlauf mit Nachdruck.
- Veranstaltungs-Druckjobs werden in `event_print_jobs` gespeichert.
- PWA-Cache auf V32.2 angehoben.
