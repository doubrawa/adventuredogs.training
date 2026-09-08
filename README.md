# Adventure Dogs — Hundeschule Julia Doubrawa

Statische Website der Hundeschule **Adventure Dogs** ([adventuredogs.training](https://adventuredogs.training/)).
Reiner HTML/CSS/JS-Stack, kein Framework, kein Build-Schritt — auf GitHub Pages gehostet.

```
adventuredogs.training/   ← Domain (eigentliche Webseite)
└─ doubrawa.github.io/    ← GitHub-Pages-Backend (CNAME-Mapping)
   └─ doubrawa/adventuredogs.training (dieses Repo)
```

---

## Wer pflegt was?

**Alles in diesem Repo.** Texte, Layout, Bilder, SEO-Infrastruktur — die Dateien hier
sind die Quelle, es gibt keine zweite Fassung woanders.

claude.ai/design wird nur noch **gelegentlich für einzelne Stücke** benutzt. Was daraus
ins Repo übernommen wird, wird im Einzelfall ausdrücklich benannt und von Hand
übertragen. Es gibt **keinen automatisierten Import mehr**, keinen Snapshot zum
Vergleichen und keine Skripte, die einen Export ins Repo überführen.

> Die frühere Pipeline (`.design/`-Snapshots, `_rederive.sh`, `post-import-fixes.sh`,
> `sync-design-icons.sh`, `swap-card-svgs.ps1`) wurde am 08.09.2026 entfernt. Alles,
> was sie nach jedem Import neu aufgesetzt hat, steht längst fest in den Seiten.
> Wer nachsehen will, was sie getan hat: `git log -- tools/post-import-fixes.sh`.

| Bereich | Wo gepflegt? |
|---|---|
| Texte, Layout, Bilder | dieses Repo, direkt in den HTML-Dateien |
| Schriften (`assets/fonts.css` + `assets/fonts/`) | dieses Repo, selbst gehostet |
| SEO (Meta, OpenGraph, JSON-LD, sitemap, robots.txt) | dieses Repo, direkt im `<head>` |
| Hosting / Domain / SSL | GitHub Pages + IONOS (DNS) |

---

## Verzeichnisstruktur

```
.                            Repo-Root = Site-Root (was unter / serviert wird)
├── index.html               Landing Page
├── angebot/index.html       Angebot (mit Filter via ?cat=…)
├── ueber-mich/index.html    Julias Geschichte + Fortbildungen
├── alltagstipps/index.html  Hub, dazu 8 Artikel in Unterordnern
├── kontakt/index.html       Kontakt + FAQ + Formspree-Formular
├── impressum/index.html     Impressum + Datenschutzerklärung
├── gebucht/index.html       Danke-Seite nach dem Formular (noindex, nicht in der Sitemap)
├── 404.html                 Fehlerseite
│
├── assets/
│   ├── *.jpg                Hero-Bilder, Offer-Card-Bilder, Portraits, Thumbs
│   ├── icon-*.png           12 Filter-Icons (PNG, light + white-Variante)
│   ├── logo.png             Site-Logo
│   ├── fonts.css            @font-face-Deklarationen (selbst gehostet)
│   └── fonts/*.woff2        DM Sans + Playfair Display, 10 Schnitte, latin subset
│
├── tools/                   Hilfsskripte (siehe unten) — kein Build, alle optional
│
├── CNAME                    "adventuredogs.training" — von GitHub auto-verwaltet
├── .nojekyll                Schaltet den Jekyll-Build aus (wir liefern fertiges HTML)
├── robots.txt               Erlaubt Crawling, verweist auf beide Sitemaps
├── sitemap.xml              14 URLs für Google/Bing
└── sitemap-images.xml       13 Einträge für die Google-Bildersuche
```

**Achtung:** Wegen `.nojekyll` liefert GitHub Pages das Repo ungefiltert aus. Alles,
was auf `main` landet, ist unter `adventuredogs.training/<pfad>` öffentlich erreichbar —
auch Ordner, die mit einem Punkt beginnen. Es gibt keinen Weg, etwas zu committen,
ohne es zu veröffentlichen. Was nicht online gehört, gehört in `.gitignore`.

---

## Werkzeuge (in `tools/`)

Keins davon läuft automatisch. Alle sind idempotent und werden bei Bedarf von Hand
aufgerufen.

### `generate-sitemap.sh`
Schreibt `sitemap.xml` neu. `lastmod` kommt aus dem letzten Commit der jeweiligen
Datei; hat sich eine Datei seit `HEAD` geändert, zählt das heutige Datum — das Skript
kann also **vor** dem Commit laufen. Artikel-Detailseiten behalten bewusst ihr
Erstelldatum, damit spätere Korrekturen es nicht verschieben.

```bash
bash tools/generate-sitemap.sh
```

### `generate-image-sitemap.ps1` (PowerShell)
Schreibt `sitemap-images.xml` neu — alle eindeutigen `/assets/`-Bilder je Seite,
für die Google-Bildersuche.

### `resize-assets.ps1` (PowerShell)
Schrumpft JPEGs auf web-vernünftige Maße: Heroes max **2400 px** Breite, sonst
**1600 px**, Qualität 82, EXIF gestrippt. Bereits passende Bilder bleiben unangetastet.

```bash
powershell -ExecutionPolicy Bypass -File tools/resize-assets.ps1 -AssetsDir "C:/DATA/Claude/adventuredogs.training/assets"
```

### `generate-thumbs.ps1` (PowerShell)
Erzeugt `thumb-<slug>.jpg` in 800 px Breite aus den Alltagstipps-Heroes. Die Karten
auf der Hub-Seite und die „Weiterlesen"-Karten rendern bei rund 400 px — der volle
Hero wäre Verschwendung.

### `crop-hero.ps1` / `resize-png.ps1` (PowerShell)
Einzelbild-Helfer. `crop-hero.ps1` beschneidet ein JPEG auf ein Seitenverhältnis und
skaliert es; `resize-png.ps1` verkleinert PNGs unter Erhalt des Alphakanals
(Logos, Icons).

### `download-fonts.sh`
Holt die WOFF2-Dateien von Google Fonts nach `assets/fonts/`. Nötig für
DSGVO-konformes Self-Hosting (LG München 2022) — die Seiten binden nie direkt bei
Google ein.

---

## Änderungen veröffentlichen

1. Dateien im Repo bearbeiten.
2. Betrifft es Seiteninhalte: `bash tools/generate-sitemap.sh` laufen lassen.
3. `git add -A && git commit && git push`
4. GitHub Pages veröffentlicht in ein bis drei Minuten.

Kommt etwas aus claude.ai/design dazu, wird der betreffende Ausschnitt von Hand
übernommen — Farben aus den `:root`-Variablen, Schriften aus `assets/fonts.css`,
Klassen aus dem Bestand. Details dazu in [CLAUDE.md](CLAUDE.md).

---

## Hosting

- **DNS**: bei IONOS (Domain-Registrar). 4× A + 4× AAAA für Apex zeigen auf GitHub-Pages-IPs (185.199.108-111.153 + 2606:50c0:8000-8003::153). 1× CNAME für `www` zeigt auf `doubrawa.github.io`.
- **Mail-Records (MX, SPF TXT, DKIM CNAMEs, DMARC)** liegen unangerührt bei IONOS — `julia@adventuredogs.training` läuft weiter über IONOS.
- **GitHub Pages** liefert die statischen Files aus, kostenlos. SSL-Zertifikat
  automatisch über Let's Encrypt — verlängert sich von selbst.
- **Custom Domain** in Repo-Settings → Pages → adventuredogs.training (verifiziert via DNS).

---

## Kontaktformular

Verwendet **[Formspree](https://formspree.io)** (Form-ID `xaqvnvzq`). Submissions
gehen per HTTP POST an `https://formspree.io/f/xaqvnvzq` und werden von dort an
die im Formspree-Dashboard hinterlegte E-Mail weitergeleitet.

Free-Tier: 50 Einreichungen/Monat. Bot-Schutz via Honeypot-Field (`_gotcha`).

Bei Form-ID-Wechsel: in `kontakt/index.html` ändern.

---

## Was Search Engines erfahren

- `robots.txt` erlaubt alles, verweist auf beide Sitemaps.
- `sitemap.xml` listet 14 URLs mit Prioritäten, `sitemap-images.xml` 13 Bildeinträge.
- LocalBusiness-JSON-LD auf der Landing → Geo + Telefon + E-Mail + Service-Area
  (Krumbach, Landkreis Günzburg, Schwaben/Bayern).
- Bei Inhalts-Updates: in Google Search Console URL-Inspection → „Indexierung
  beantragen" pusht das Update zu Google.

---

## Bei Problemen — was zuerst checken?

| Problem | Erste Diagnose |
|---|---|
| Seite zeigt alte WordPress-Inhalte | Lokaler DNS-Cache. `ipconfig /flushdns` oder Mobilfunk-Test. |
| HTTPS-Fehler nach Domain-Änderung | Let's-Encrypt-Provisioning kann 5-30 Min dauern; in GitHub Pages Settings „Remove + Re-Add" der Custom Domain triggert frisch. |
| Bild fehlt oder ist riesig | Liegt es in `assets/`? Ist der Pfad relativ korrekt (Unterseiten brauchen `../assets/…`)? Danach `resize-assets.ps1`. |
| Sitemap-Datum stimmt nicht | `bash tools/generate-sitemap.sh` — es leitet `lastmod` aus git ab. |
| Form-Mails kommen nicht an | Erste Formspree-Verifizierungs-Mail evtl. übersehen → Formspree-Dashboard prüfen. |
| Google indexiert eine Seite nicht | URL-Inspection in Search Console → „Live test" + „Indexierung beantragen". Kann 1-3 Tage dauern. |

---

## Lizenz

Privater Code für eine konkrete Webseite. Keine offizielle Lizenz hinterlegt —
nicht zur Wiederverwendung gedacht.
