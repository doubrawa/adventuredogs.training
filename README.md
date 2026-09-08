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
│   ├── *.webp               alles, was im Browser gerendert wird
│   ├── hero-*.jpg           dieselben Heroes als JPEG — nur für og:image
│   ├── logo.svg / logo.png  Site-Logo
│   ├── fonts.css            @font-face-Deklarationen (selbst gehostet)
│   └── fonts/*.woff2        DM Sans + Playfair Display, drei variable Fonts
│
├── tools/                   Hilfsskripte (siehe unten)
│   ├── pages.tsv            die Seitenliste — einzige Quelle für beide Sitemaps
│   └── hooks/pre-commit     erzeugt die Sitemaps neu und prüft die Seite
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

Alle sind idempotent. Die ersten drei ruft der `pre-commit`-Hook selbst auf, der Rest
wird bei Bedarf von Hand gestartet.

### `pages.tsv` — die Seitenliste
Keine Skriptdatei, sondern **die einzige Quelle**, welche Seiten es gibt: URL, Datei,
`changefreq`, Priorität, woher `lastmod` kommt, und ob die Seite in die Bild-Sitemap
gehört. `generate-sitemap.sh`, `generate-image-sitemap.ps1` und `check-site.py` lesen
alle daraus. **Eine neue Seite wird hier eingetragen** — sonst fehlt sie in den
Sitemaps, und `check-site.py` sagt genau das.

### `check-site.py`
Prüft, was sonst niemand prüft, und endet bei Fehlern mit Exit 1:

| Prüfung | worauf |
|---|---|
| Seitenliste | deckt sich `pages.tsv` mit den HTML-Dateien auf der Platte? |
| SEO | hat jede Seite `title`, `description`, `canonical`, `og:title`, `og:image`, `viewport` — und zeigt das canonical auf die eigene URL? |
| Verweise | lösen alle internen `href`/`src` auf existierende Dateien auf? |
| Sitemaps | wohlgeformtes XML, deckungsgleich mit `pages.tsv`, keine toten Bild-URLs |
| Bilder | nichts breiter als 2400 px; nichts, das ein Besucher lädt, schwerer als 700 KB; keine Datei in `assets/`, auf die niemand zeigt |
| Seitengewicht | Summe aus HTML, Schriften und allen referenzierten Bildern je Seite |

```bash
py tools/check-site.py
```

### `generate-sitemap.sh`
Schreibt `sitemap.xml` aus `pages.tsv`. `lastmod` kommt aus dem letzten Commit der
jeweiligen Datei; hat sich eine Datei seit `HEAD` geändert, zählt das heutige Datum —
das Skript kann also **vor** dem Commit laufen. Artikel-Detailseiten behalten bewusst
ihr Erstelldatum (Spalte `lastmod = anlage`), damit spätere Korrekturen es nicht
verschieben.

```bash
bash tools/generate-sitemap.sh
```

### `generate-image-sitemap.ps1` (PowerShell)
Schreibt `sitemap-images.xml` neu — alle eindeutigen `/assets/`-Bilder je Seite,
für die Google-Bildersuche. Nimmt die Seiten mit `bilder = ja` aus `pages.tsv`.

### Bildformate: WebP für Besucher, JPEG für Crawler

Seit dem 08.09.2026 ist **alles, was der Browser rendert, WebP** — `<img src>`,
CSS-Hintergründe und Preloads. Das spart rund ein Drittel: 2,7 MB über alle Bilder,
auf der Startseite 285 → 131 KB allein für den Hero.

Die Heroes liegen zusätzlich als **JPEG** daneben, weil `og:image`, `twitter:image`
und das `image`-Feld im JSON-LD darauf zeigen: Social-Crawler gehen mit WebP
unzuverlässig um, und eine fehlende Vorschau beim Teilen wiegt schwerer als ein
paar Kilobyte, die ohnehin kein Besucher lädt.

Bewusst **kein `<picture>`-Fallback**: das würde jedes `<img>` in ein zusätzliches
Element hüllen und CSS-Regeln brechen, die auf direkte Kindelemente zielen. WebP
kann jeder Browser seit Safari 14 (2020).

Ein neues Bild kommt also als JPEG nach `assets/`, wird mit `resize-assets.ps1`
auf Maß gebracht und dann nach WebP gewandelt; im HTML steht die `.webp`, im
`og:image` die `.jpg`. `check-site.py` merkt es, wenn eins von beidem fehlt.

### `resize-assets.ps1` (PowerShell)
Schrumpft JPEGs auf web-vernünftige Maße: Heroes max **2400 px** Breite, sonst
**1600 px**, Qualität 82, EXIF gestrippt. Bereits passende Bilder bleiben unangetastet.

```bash
powershell -ExecutionPolicy Bypass -File tools/resize-assets.ps1 -AssetsDir "C:/DATA/Claude/adventuredogs.training/assets"
```

### `generate-thumbs.py`
Erzeugt `thumb-<slug>.webp` in 800 px Breite aus den Alltagstipps-Heroes. Die Karten
auf der Hub-Seite und die „Weiterlesen"-Karten rendern bei rund 400 px — der volle
Hero wäre Verschwendung. Baut nur neu, was älter ist als seine Quelle; `--force`
erzwingt alles.

Löste am 08.09.2026 `generate-thumbs.ps1` ab: System.Drawing, das die
PowerShell-Fassung benutzte, kann kein WebP schreiben.

### `crop-hero.ps1` / `resize-png.ps1` (PowerShell)
Einzelbild-Helfer. `crop-hero.ps1` beschneidet ein JPEG auf ein Seitenverhältnis und
skaliert es; `resize-png.ps1` verkleinert PNGs unter Erhalt des Alphakanals
(Logos, Icons).

### `download-fonts.sh`
Holt die WOFF2-Dateien von Google Fonts nach `assets/fonts/`. Nötig für
DSGVO-konformes Self-Hosting (LG München 2022) — die Seiten binden nie direkt bei
Google ein.

Beide Familien kommen als **variable Fonts**: eine Datei deckt die ganze
Gewichtsachse ab. Deshalb liegen dort nur drei Dateien statt zehn. Bis zum
08.09.2026 lagen dieselben drei Dateien unter zehn Namen im Ordner, und der Browser
lud jede einzeln — 370 KB, von denen 259 KB reine Wiederholung waren. Das Skript
prüft die Annahme bei jedem Lauf: fällt eine Familie nicht mehr auf genau eine
Prüfsumme zusammen, bricht es ab, statt still ein Gewicht für alle auszuliefern.

---

## Änderungen veröffentlichen

Einmalig je Arbeitskopie den Hook aktivieren — `.git/hooks` ist nicht versioniert,
`tools/hooks` schon:

```bash
git config core.hooksPath tools/hooks
```

Danach:

1. Dateien im Repo bearbeiten. Neue Seite? Dann in `tools/pages.tsv` eintragen.
2. Neue oder ausgetauschte Bilder: `powershell -ExecutionPolicy Bypass -File tools/resize-assets.ps1`
3. `git status` — schauen, was wirklich mitgeht.
4. `git add <pfade>` (gezielt; `git add -A` nimmt auch mit, was nur zufällig im Baum liegt)
5. `git commit` — der Hook erzeugt beide Sitemaps neu und lässt `check-site.py` laufen.
   Bricht er ab, sagt er warum. Im Notfall: `git commit --no-verify`.
6. `git push` — GitHub Pages veröffentlicht in ein bis drei Minuten.

Ohne Hook (oder zur Kontrolle zwischendurch) sind es dieselben drei Aufrufe von Hand:

```bash
bash tools/generate-sitemap.sh && powershell -ExecutionPolicy Bypass -File tools/generate-image-sitemap.ps1 && py tools/check-site.py
```

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
