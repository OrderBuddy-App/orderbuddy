# OrderBuddy – Update-Paket

Dieses Paket enthält die gesammelten Änderungen aus der Testphase.

## Sichtbare Änderungen
- Browser-Titel auf `OrderBuddy` gekürzt und OrderBuddy-Logo als Favicon ergänzt.
- Wortmarke im Header auf `OrderBuddy` statt Versalien vereinheitlicht.
- Beige/NOVA-Farbreste durch neutrales OrderBuddy-Design ersetzt.
- Service-Auswertung gegen überlappende E-Mail-/Balkendarstellung abgesichert.
- Lieferorte auf generische `Lieferzone 1–5` umgestellt; Name, Preis und Aktivstatus sind im Chefbereich editierbar.
- Servicebereich um `Gutschein prüfen` ergänzt. Restwert und Gültigkeit können geprüft sowie Teil-/Volleinlösungen dokumentiert werden; es wird keine Zahlungsart erfasst.
- Tagesabschluss als kompakter Bon und als A4-PDF-Druckansicht ergänzt.
- Monatsabschluss als kompakter Bon und als A4-PDF-Druckansicht ergänzt.
- Monatliche DATEV-EXTF-Exporte ergänzt:
  - Einzelpositionen
  - Tagessummen
- Manuelle Monatsbuchungen ergänzt:
  - Geldtransit 1360
  - Privatentnahme 1800
  - Privateinlage 1890
  - Kosten mit frei wählbarem Kostenkonto und optionalem BU-Schlüssel
- DATEV-Beraternummer, Mandantennummer, Wirtschaftsjahr und Sachkontenlänge können in den Einstellungen hinterlegt werden.

## Vor dem ersten Einsatz
1. In Supabase den SQL Editor öffnen.
2. `SUPABASE_ORDERBUDDY_UPGRADE.sql` ausführen.
3. Danach OrderBuddy neu laden.
4. Im Chefbereich unter **Einstellungen → DATEV-Einstellungen** die DATEV-Stammdaten hinterlegen.

## DATEV-Hinweis
Die EXTF-Dateien verwenden DATEV Header-Version 700 und den Buchungsstapel. Vor produktiver Übergabe sollten Berater-/Mandantendaten sowie die Kontierung einmal mit der Steuerkanzlei geprüft und ein Testimport durchgeführt werden.

## Legacy-Kompatibilität
Die bisher intern verwendeten Supabase-RPC-Namen mit `nova` wurden auf `orderbuddy` umgestellt. Vor dem nächsten Einsatz muss `SUPABASE_ORDERBUDDY_RPC_RENAME.sql` einmal in Supabase ausgeführt werden. Gutschein-QR-Codes verwenden ausschließlich `ORDERBUDDY-GUTSCHEIN`; alte NOVA-Testcodes werden nicht mehr akzeptiert.
