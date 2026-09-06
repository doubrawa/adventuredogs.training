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
| Preview-Banner (35) | `<div class="preview-note">Vorschau · …</div>` am Ende des Alltagstipps-Exports — interne Notiz, ohne CSS-Regel, stand als Fliesstext unter dem Footer live auf der Seite |
| Nav-Media-Query (53) | Untergrenze 821 → 961 px; der Bereich darunter läuft ins Leere, weil ab 960 px der Hamburger übernimmt |
| Nav-Geometrie (69) | Balken, Rand, Logo, Linkabstand, Linkschrift, CTA-Polster auf die officedogs-Werte — **officedogs ist die Referenz** |
| Sprungmarken (120) | `scroll-margin` in den Artikeln 90 → 100 px, weil die Nav jetzt 80 px hoch ist |
| Hero-Badge (132) | WhatsApp-Kanal statt Kurs-Event: nur das Logo im Kreis, kleinerer Kreis, Ringtext, `data-expires="2026-12-31"`, Teal |
| Impressum TMG → DDG (305) | Gesetzesname, reine Textänderung |
| Hero-Preload (566) | `<link rel="preload" as="image">` auf den Unterseiten; deren Hero ist ein CSS-Hintergrund, den der Preload-Scanner nicht findet — die Startseite hat dafür ihr `<img fetchpriority="high">` |
| Kontakt-FAQ (590) | fünf zusätzliche Frage-Antwort-Paare |
| Hub-Karte hund-entlaufen (636) | fehlt im Design-Hub |
| FAQ-Accordion (774) | `aria-expanded` für Screenreader |
| rel-Attribute (793) | externe Empfehlungslinks |
| 1320er-Deckel im Angebot (915) | `.services-header`/`.services-grid` zentriert auf 1320 px – als einzige Blöcke der Seite; ab 1535 px Fensterbreite kippt dadurch die linke Kante weg |

Der Asset-Name-Block (22) bleibt in der Pipeline: das Design lädt das Foto
selbst hoch und kann unseren optimierten Dateinamen nicht kennen.

### Ohne Netz — nur im Repo, nicht in der Pipeline

Aus dem Code-Review vom 06.09.2026. Alle sieben sitzen in Design-Dateien, werden
aber von keinem Pipeline-Block wieder aufgesetzt: ein Import bringt den alten
Stand zurück.

| Stelle | worum es geht |
|---|---|
| `index.html` `.intro-cols` | `@media (max-width: 1500px)` → `1499.98px`. Bei exakt 1500 px trafen beide Queries zu, die erzwungenen Spaltenumbrüche verlangten drei Spalten in einem zweispaltigen Raster, und der dritte Absatz stand 570 px außerhalb — von `overflow-x: hidden` abgeschnitten |
| `index.html` `.intro-close` | `font-style: italic` raus. Der große kursive Playfair-Satz gehört Julias Versprechen in `#julia`; der Schlusssatz sagt fast dasselbe in derselben Schrift, Farbe und bis auf 2 px derselben Größe (siehe CLAUDE.md, „Playfair-Kursiv ist reserviert") |
| `kontakt/index.html` `<form>` | `novalidate` raus. Damit war die Browser-Validierung abgeschaltet und der Handler brach bei leeren Feldern stumm ab — Klick auf „Nachricht senden", und sichtbar passierte nichts. Der Handler fängt jetzt zusätzlich Eingaben aus reinen Leerzeichen ab, die `required` besteht |
| `angebot/index.html` Termine-Block | Drei Eingriffe. `.termine-inner`: `max-width: 900px; margin: 0 auto` raus — der einzige zentrierte Block der Seite, dadurch 370 px weiter innen als die Nachbarabschnitte bei 1920 px (siehe CLAUDE.md, „nur der Seitenrand, kein Deckel"). `.termine-section`: `border-radius: var(--r-lg)` dazu, damit der getönte Block eine Karte ist wie das CTA-Banner und die Angebotskarten — gleiche linke Kante, gleiche Rundung. Die 7 % Innenabstand sind dadurch Kartenpolster statt Versatz. `.termine-section h2` und `.termine-consent h3`: `font-weight` 800 → 700 wie jede andere Playfair-Überschrift — einen 800er-Schnitt gibt es gar nicht, der Browser griff zu Playfair 900 (gemessen: 800 und 900 rendern zeichengleich) |
| alle Unterseiten, `<img>` | `width`/`height` nachgetragen. Betraf die Offer-Bilder und die Anfahrtsskizze wirklich (`height: auto`, kein reservierter Platz); bei Karten und Icons reserviert das CSS die Box schon, dort ist es Gleichmaß. Für die vom Skript erzeugten Karten steht es in `swap-card-svgs.ps1` |
| alle Seiten, Nav | Klassen `nav-od` / `nav-od-mobile` raus — im Markup von 16 Seiten, ohne eine einzige CSS-Regel |
| `kontakt/index.html` | leere Regel `.contact-form-wrap {}` raus |

Der Intro-Block „Kurz vorweg“ stand hier, bis er am 06.09.2026 ins
Design-Projekt wanderte; seine Fassung von dort wurde von Hand übernommen
(`.intro-note` / `.intro-cols` in `index.html`).

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
