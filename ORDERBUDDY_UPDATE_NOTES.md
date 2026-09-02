# OrderBuddy V32.0 – konsolidierter Stabilitätsumbau

Basis ausschließlich: vom Nutzer am 03.09.2026 hochgeladene `orderbuddy-main(1).zip`.

- Gutschein-RPCs vollständig ergänzt: Verkauf, Veranstaltung-Verkauf, Einlösung, Entfernen/Storno.
- Abrechnung für normale Vorgänge auf atomare Supabase-RPCs umgestellt.
- „Alle Positionen zuerst erledigen“ ist jetzt eine echte Sammelaktion; danach folgt bewusst Grün.
- Veranstaltungen V-1 bis V-8 verwenden in Übersicht und Detail dieselben Statusfarben/Komponenten wie Terrasse/Innenraum.
- Farblegende ist auch unter Veranstaltungen sichtbar.
- Veranstaltungspaket ist die erste normale Positionszeile, aber nicht stornierbar.
- Gutschein verkaufen / Gutschein prüfen ist auch bei Veranstaltungen verfügbar.
- Veranstaltungs-Gutscheine werden im Gesamtbetrag und als 0-%-Zeile im Gesamtbon berücksichtigt.
- Auswertungen/DATEV verwenden Gutscheinverkäufe nur, wenn der zugehörige Tisch/Auftrag bzw. die Veranstaltung abgeschlossen ist.
- Gelöschte abgeschlossene Tischvorgänge bleiben durch physisches Löschen aus allen späteren Auswertungen entfernt.
- PWA-Cache auf V32.0 angehoben.

V32.1: SQL-Kompatibilitätsfix für bestehende create_orderbuddy_voucher-Funktion (42P13).
