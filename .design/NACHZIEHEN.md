# Was noch ins claude.ai/design-Projekt gehört

**Offene Aufgabe (Stand 11.08.2026).** Beide Sites laufen produktiv mit Fixes,
die *nach* dem Design-Export aufgesetzt werden. Ein Teil davon gehört
eigentlich ins Design — solange er dort fehlt, wird er bei jedem Import neu
aufgesetzt, und jeder neue Export bringt den alten Stand wieder mit.

Diese Liste ist eine **Wegweiser-Liste, kein Prompt**: sie sagt, *welche*
Blöcke ins Design müssen und wo sie stehen. Die konkreten Werte, Maße und
Begründungen stehen im jeweiligen Block als Kommentar — dort und nur dort,
damit sie nicht an zwei Stellen auseinanderlaufen. Wer den Design-Prompt
schreibt, liest die Blöcke und formuliert daraus; wer diese Datei pflegt,
streicht erledigte Zeilen.

Das Design-Projekt heißt **„Adventure Dogs Training"** und bedient beide
Sites. Die produktive OfficeDogs-Seite darin ist **„Office Dogs Vollbild
Logo"** (es gibt mehrere Varianten, nur diese zählt).

## adventuredogs.training — `tools/post-import-fixes.sh`

| Block (Zeile) | worum es geht |
|---|---|
| Nav-Media-Query (35) | Untergrenze 821 → 961 px; der Bereich darunter läuft ins Leere, weil ab 960 px der Hamburger übernimmt |
| Nav-Geometrie (51) | Balken, Rand, Logo, Linkabstand, Linkschrift, CTA-Polster auf die officedogs-Werte — **officedogs ist die Referenz** |
| Sprungmarken (102) | `scroll-margin` in den Artikeln 90 → 100 px, weil die Nav jetzt 80 px hoch ist |
| Hero-Badge (114) | WhatsApp-Kanal statt Kurs-Event: nur das Logo im Kreis, kleinerer Kreis, Ringtext, `data-expires="2026-12-31"`, Teal |
| Impressum TMG → DDG (287) | Gesetzesname, reine Textänderung |
| Kontakt-FAQ (511) | fünf zusätzliche Frage-Antwort-Paare |
| Hub-Karte hund-entlaufen (553) | fehlt im Design-Hub |
| FAQ-Accordion (699) | `aria-expanded` für Screenreader |
| rel-Attribute (711) | externe Empfehlungslinks |
| 1320er-Deckel im Angebot (845) | `.services-header`/`.services-grid` zentriert auf 1320 px – als einzige Blöcke der Seite; ab 1535 px Fensterbreite kippt dadurch die linke Kante weg |

Der Asset-Name-Block (22) bleibt in der Pipeline: das Design lädt das Foto
selbst hoch und kann unseren optimierten Dateinamen nicht kennen.

### Ohne Netz — nur im Repo, nicht in der Pipeline

| Was | worum es geht |
|---|---|
| Intro-Block „Kurz vorweg“ (`index.html`, direkt vor `<!-- SERVICES -->`) | Fünfsätziger Erzählblock zwischen Trust-Bar und Angebot, am 05.09.2026 direkt im Repo gebaut. Kicker, Playfair-Einstieg, Haarlinie, zweispaltiger Fließtext mit Initial, kursive Schlusszeile. Kein Container und kein Deckel – der Block füllt die Sektionsbreite wie die Nachbarabschnitte; die Zeilenlänge regeln Spaltenzahl (3 ab 1500 px, 2 darunter, 1 unter 900 px) und ein mitwachsender Schriftgrad. |

Anders als die Blöcke darüber setzt **kein** Skript das wieder auf: Der nächste Export aus
claude.ai/design bringt die Landing Page ohne diesen Abschnitt zurück, und
`post-import-fixes.sh` merkt davon nichts. Entweder wandert der Block ins Design-Projekt
(dann diese Zeile streichen) oder er braucht einen eigenen Block in `post-import-fixes.sh`,
der ihn nach jedem Import wieder einsetzt.

## officedogs.training — `tools/_rederive.sh`

| Block | worum es geht |
|---|---|
| Querverweise (47) | Links auf die Hauptsite absolut, nicht relativ |
| Handlungsaufforderungen (67) | „Gespräch vereinbaren" / „Anfrage senden" auf `adventuredogs.training/kontakt/` statt auf den Anker `#kontakt` — die Sektion hier hat kein Formular, nur wieder einen Knopf |
| Title und Description (82) | |
| Produktname (103) | „Office Dog Guide" → „Office Dogs **Guide**" |
| Hero-Schleier (162) | |
| Marke in der Kopfzeile (206) | Zusatz „Adventure Dogs · Julia Doubrawa" neben dem Logo raus |
| Bildpanel (227) | Julia groß als Panel statt im 200-px-Kreis |
| Struktur (315) | `<main>`-Landmark; `alt=""` am dekorativen zweiten Logo |

Zwei Blöcke laufen seit Export v53 **leer** und bleiben nur als Netz stehen:
E-Mail-Adresse (112, das Design lieferte `info@adventuredogs.training` — die
Adresse existiert nicht) und Preisangabe (118, „zzgl. MwSt." bei einer
Kleinunternehmerin).

## Was dauerhaft in der Pipeline bleibt

Kein Versäumnis, sondern Absicht — ein visuelles Werkzeug ist der falsche Ort
dafür: Favicons, Unterseiten-Pfade, SEO-/OpenGraph-/Twitter-Blöcke, sämtliches
JSON-LD (LocalBusiness, Article, FAQPage, BreadcrumbList), Thumbnail-Varianten
und der SVG→IMG-Tausch auf dem Hub, das „Veröffentlicht"-Datum, beide Sitemaps.

## Nicht im Design suchen

- **Beide Impressum-Seiten sind handgepflegt.** `impressum/index.html` wird von
  keiner der zwei Pipelines angefasst; Änderungen dort direkt vornehmen.
- **Der OfficeDogs-One-Pager** (`officedogs.training/tools/onepager/`) ist eine
  eigene Datei, kein Design-Export. Er kopiert Farben und Bausteine der Site
  von Hand — wer die Palette ändert, muss dort nachziehen. Siehe
  `officedogs.training/DEPLOY.md`, Abschnitt 5.
