# Hinweise für die Arbeit an dieser Seite

Ergänzung zur [README.md](README.md), die Aufbau, Pipeline und Hosting beschreibt.
Hier steht nur, was man beim Bearbeiten der Seiten leicht falsch macht.

## Layout: nur der Seitenrand, kein Deckel

Die Sektionen der Seite stehen in **7 % Seitenrand** (`section { padding: 90px 7% }`,
bis einschließlich 720 px `64px 5%`) und laufen darin **über die volle Breite**. Einen
zentrierten Maximalbreiten-Container gibt es nicht: `.method-grid`, `.julia-section`,
`.testimonials-grid` und `.services-grid` beginnen alle bei 7 %.

Ein neuer Block braucht deshalb **gar keinen äußeren Container**. Ein `margin: 0 auto`
auf einem gedeckelten Block zentriert ihn und schiebt seine linke Kante nach innen,
während die Nachbarabschnitte bei 7 % bleiben.

**Und ein Deckel ohne `auto` löst es auch nicht.** Linksbündig gekappt fluchtet die Kante
zwar, dafür bleibt rechts ein wachsender Streifen leer – beim Intro-Block waren das bei
2000 px rund 620 px, ein Drittel der Sektion. Zwischen den vollbreiten Nachbarabschnitten
sieht das unfertig aus.

**Lesbare Zeilen kommen deshalb nicht aus einem Deckel, sondern aus der Aufteilung:**
mehr Spalten und ein mitwachsender Schriftgrad, damit der Block die Sektionsbreite füllt
und die Zeile trotzdem unter 75 Zeichen bleibt – siehe `.intro-cols`:

```css
.intro-cols { column-count: 3; column-gap: 72px; }
@media (max-width: 1500px) { .intro-cols { column-count: 2; } }
@media (max-width: 900px)  { .intro-cols { column-count: 1; } }
.intro-cols p { font-size: clamp(17px, 1.05vw, 22px); break-inside: avoid; }
@media (min-width: 1500px) { .intro-cols p:not(:last-child) { break-after: column; } }
```

Gemessen läuft das von 375 bis 3000 px zwischen 40 und 73 Zeichen je Zeile.

**Die Falle:** Ein Deckel unter der Sektionsbreite fällt bei schmalen Fenstern nicht auf.
Bei 1280 px ist der Inhaltsbereich nur 1100 px breit, ein 1320er-Deckel greift dort also
gar nicht – alle Werte zwischen 1100 und 1320 liefern exakt dasselbe Bild. Sichtbar wird
es erst darüber: ein zentrierter 1320er-Block stand bei 1920 px um 159 px, bei 3000 px
um 623 px weiter innen als der Abschnitt darunter. Genau das hatten Intro und Angebot,
bis es am 05.09.2026 herausgenommen wurde.

**Also:** Layoutänderungen immer auch bei **1920 px und breiter** ansehen, nicht nur bei
1280, und die linke Kante gegen den Abschnitt darüber und darunter prüfen – am besten
gemessen (`getBoundingClientRect().left`) statt geschätzt.

## Schriften und Farben kommen aus dem Bestand

Farben ausschließlich aus den `:root`-Variablen in `index.html` (`--blue`, `--accent`,
`--cream`, `--cream2`, `--text-lt`, …), keine neu erfundenen Werte. Schriften sind
DM Sans (300/400/500/600) und Playfair Display (600/700/900, dazu kursiv) — selbst
gehostet über `assets/fonts.css`, andere Schnitte gibt es nicht.

Für wiederkehrende Bausteine die vorhandenen Klassen nutzen statt sie nachzubauen:
`.section-label` für die kleine Versalzeile über einer Überschrift, `.section-title`,
`.section-sub`, `.btn-primary`, `.btn-ghost`.

## Playfair-Kursiv ist reserviert

Der große kursive Serifensatz gehört Julias Versprechen in der `#julia`-Sektion
(„Dein Leben mit Hund kann schöner werden, als du es dir vorgestellt hast."). Ein zweiter
kursiver Playfair-Block auf derselben Seite nimmt ihm die Wirkung — besonders, wenn er
inhaltlich dasselbe sagt.

## Nicht ungefragt committen oder pushen

GitHub Pages veröffentlicht jeden Push innerhalb von ein bis drei Minuten live.
Änderungen erst zeigen, dann auf Zuruf committen.

Den Rest erledigt der `pre-commit`-Hook (`git config core.hooksPath tools/hooks`):
er erzeugt beide Sitemaps neu — und nimmt sie gleich mit in den Commit, falls sie
nicht aktuell waren — und lässt `tools/check-site.py` laufen: Seitenliste,
SEO-Blöcke, interne Verweise, Bildmaße, Seitengewicht. Bricht er ab, ist etwas
wirklich kaputt; `--no-verify` ist für Notfälle, nicht für Bequemlichkeit.

Von Hand nur zwei Dinge:

- **Neue Seite?** In `tools/pages.tsv` eintragen. Das ist die einzige Quelle für
  beide Sitemaps; wer sie vergisst, wird vom Hook daran erinnert.
- **Neue Bilder?** `resize-assets.ps1` laufen lassen, dann nach WebP wandeln.
  Im HTML steht die `.webp`, im `og:image` bleibt die `.jpg` — Social-Crawler
  kommen mit WebP nicht zuverlässig zurecht. Kein `<picture>`: der zusätzliche
  Wrapper bricht CSS-Regeln, die auf direkte Kindelemente zielen.
  `sitemap.xml` dagegen nie von Hand anfassen — sie wird erzeugt.

Und weil `.nojekyll` gesetzt ist, liefert Pages das Repo ungefiltert aus: **alles auf
`main` ist öffentlich erreichbar**, Punkt-Ordner eingeschlossen. Etwas committen und
zugleich nicht veröffentlichen geht nicht — was nicht online gehört, gehört in
`.gitignore` (so wie `willkommensmappe/`).

## Es gibt keinen Design-Import mehr

claude.ai/design ist nicht mehr die Quelle dieser Seite; die Dateien im Repo sind es.
Das Tool wird nur noch gelegentlich für einzelne Stücke benutzt, und was daraus
übernommen wird, sagt Jürgen ausdrücklich — übertragen wird von Hand, mit den
Farben, Schriften und Klassen aus dem Bestand.

Die alte Pipeline (`.design/`-Snapshots, `_rederive.sh`, `post-import-fixes.sh`,
`sync-design-icons.sh`, `swap-card-svgs.ps1`, dazu `NACHZIEHEN.md`) ist am 08.09.2026
entfernt worden. Keinen Diff gegen einen Export bauen, keine Snapshots pflegen, keine
Fixes „nachziehen" — alles, was diese Skripte taten, steht fest in den Seiten.
