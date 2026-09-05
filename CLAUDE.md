# Hinweise für die Arbeit an dieser Seite

Ergänzung zur [README.md](README.md), die Aufbau, Pipeline und Hosting beschreibt.
Hier steht nur, was man beim Bearbeiten der Seiten leicht falsch macht.

## Layout: zwei Container, nicht einer

Die Sektionen der Seite stehen in **7 % Seitenrand** (`section { padding: 90px 7% }`,
bis einschließlich 720 px `64px 5%`), und ihr Inhalt läuft darin in einem **auf 1320 px gedeckelten,
zentrierten Container** — siehe `.services-header` und `.services-grid` in `index.html`.

Ein neuer Block muss **denselben 1320er-Container** benutzen, sonst fluchtet seine linke
Kante nicht mit den Nachbarabschnitten. Wer die Lesebreite begrenzen will, kappt sie in
einem **zweiten, inneren** Container:

```html
<div class="intro-story-inner">   <!-- 1320 px zentriert: Flucht mit den Sektionen -->
  <div class="intro-story-text">  <!-- 1100 px: Satzspiegel -->
```

**Die Falle:** Unterhalb von rund 1535 px Fensterbreite greift der 1320er-Deckel gar nicht,
weil die 7 % Rand vorher aufgebraucht sind. Bei 1280 px liefern deshalb *alle* Deckelwerte
zwischen 1100 und 1320 px exakt dasselbe Ergebnis — der Fehler ist dort unsichtbar.
Er zeigt sich erst darüber: beim Intro-Block waren es 63 px Versatz bei 1440 px und
110 px bei 1920 px.

**Also:** Layoutänderungen immer auch bei **1600 und 1920 px** ansehen, nicht nur bei 1280,
und die linke Kante gegen den Abschnitt darüber oder darunter prüfen.

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
Änderungen erst zeigen, dann auf Zuruf committen. Beim Push mitziehen:

- `<lastmod>` der betroffenen URL in `sitemap.xml` auf das Datum der Änderung
- Direkt am Repo geänderte Inhalte in `.design/NACHZIEHEN.md` eintragen, sonst sind sie
  beim nächsten Import aus claude.ai/design wieder weg (siehe `.design/README.md`)
