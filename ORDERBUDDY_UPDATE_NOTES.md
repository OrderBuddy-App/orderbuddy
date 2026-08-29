# OrderBuddy – Umbau V3

Neu bzw. korrigiert:

- Standard-Wechselgeld pro Restaurant frei einstellbar unter **Einstellungen → Kasse / Wechselgeld**.
- Der Bargeldsaldo startet je aktivem Betriebstag mit dem hinterlegten Standard-Wechselgeld und führt danach Bar-Umsätze sowie manuelle Bargeldbewegungen fort.
- Ausgaben werden weiterhin blockiert, wenn der Tages-Bargeldsaldo rechnerisch unter 0,00 € fallen würde.
- Tischübersicht mit Statusfarben: frei, besetzt/offen, in Zubereitung, fertig/Service, bereit zum Abschluss.
- Lieferung und Abholung bleiben belegt, bis der Auftrag tatsächlich abgeschlossen wurde. Die Abschluss-Schaltfläche nennt Fahrer/Geldrücklauf bzw. Abholung ausdrücklich.
- Nach Abschluss wird der Liefer-/Abholplatz wieder frei.
- Tagesabschluss zählt und zeigt nur abgeschlossene Vorgänge mit echtem Umsatz bzw. gültigem Gutscheinvorgang; vollständig stornierte/leere Sitzungen erscheinen nicht mehr als abgeschlossene Tische.
- Die vier DATEV-Varianten bleiben erhalten: automatische Einzelpositionen, automatische Tagessummen, komplette Einzelpositionen inkl. manueller Buchungen und komplette Tagessummen inkl. manueller Buchungen.
- Die fünfte Monats-CSV bleibt ausschließlich für Nicht-Bar-Zahlungen.
- Zahlungsarten: Bar, Girocard/EC, Kreditkarte, Apple Pay, Google Pay, Gutschein, Überweisung, Online-Zahlung, Sonstiges; Mischzahlungen sind möglich.
- Lieferung erzeugt Küchen- und Fahrerbon; Abholung Küchen- und Abhol-/Kassenbon. Nachbestellungen drucken nur neue Positionen auf den Zusatzbons.
- PWA-Ausbau für iPhone/iPad/Mac: erweitertes Manifest, Apple-Web-App-Metadaten und Service Worker für installierbaren App-Betrieb.

## Vor dem Hochladen

Einmal **SUPABASE_ORDERBUDDY_UPGRADE_V3.sql** im Supabase SQL Editor ausführen.
Danach die Dateien nach GitHub hochladen und Vercel deployen lassen.


## V4 – PWA-Name, App-Icon, Tischfarben
- PWA-/App-Name auf **OrderBuddy** verkürzt.
- App-Icon durch quadratische Version ohne transparente Unterkante ersetzt.
- Tischstatus färbt jetzt die komplette Tischkachel (frei, besetzt, Zubereitung, Service, Abschluss).
- Service-Worker-Cache auf V4 angehoben, damit Manifest, Icon und Styles nach dem Deployment aktualisiert werden.


## V5 Tischstatus-Synchronisierung
- Tischstatus wird sofort nach Neu/Zubereitung/Erledigt neu berechnet.
- Beim Zurückkehren zur Tischübersicht werden Status und Farben vor dem Anzeigen aktualisiert.
- PWA-Cache auf v5 erhöht, damit installierte Apps den Patch übernehmen.
