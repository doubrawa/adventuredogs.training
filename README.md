# Adventure Dogs — Hundeschule Julia Doubrawa

Statische Website der Hundeschule **Adventure Dogs** ([adventuredogs.training](https://adventuredogs.training/)).
Reiner HTML/CSS/JS-Stack, kein Framework, kein Build-Schritt — auf GitHub Pages gehostet.

```
adventuredogs.training/   ← Domain (eigentliche Webseite)
└─ doubrawa.github.io/    ← GitHub-Pages-Backend (CNAME-Mapping)
   └─ doubrawa/adventuredogs.training (dieses Repo)
```

---

## Wer ist wofür zuständig?

Die Inhalte und das visuelle Design entstehen in **[claude.ai/design](https://claude.ai/design)** —
einem KI-Design-Tool. Dort werden Texte, Layouts, Bilder bearbeitet. Bei jeder Änderung
wird ein ZIP-Bundle exportiert, durch eine **Pipeline** in dieses Repo importiert, und
die Live-Seite aktualisiert sich automatisch über GitHub Pages.

Aufteilung der Verantwortlichkeiten:

| Bereich | Wo gepflegt? |
|---|---|
| Texte, Layout, Bilder, Design | **claude.ai/design** |
| Schriften (`assets/fonts.css` + Naming-Konvention) | claude.ai/design |
| Filter-Logik, Mobile-Nav, etc. | claude.ai/design |
| Pipeline-Scripts (URL-Substitution, Bild-Resize, Icons-Sync) | dieses Repo |
| SEO-Infrastruktur (Meta, OpenGraph, JSON-LD, sitemap, robots.txt) | dieses Repo |
| Hosting / Domain / SSL | GitHub Pages + IONOS (DNS) |

---

## Verzeichnisstruktur

```
.                            Repo-Root = Site-Root (was unter / serviert wird)
├── index.html               Landing Page
├── kontakt/index.html       Kontakt + FAQ + Formspree-Formular
├── angebot/index.html       Angebot (mit Filter via ?cat=…)
├── alltagstipps/index.html  Tipps zu Welpe / Silvester / Urlaub / etc.
├── impressum/index.html     Impressum + Datenschutzerklärung
├── ueber-mich/index.html    Julias Geschichte + Fortbildungen
│
├── assets/
│   ├── *.jpg                Hero-Bilder, Offer-Card-Bilder, Portraits
│   ├── icon-*.png           12 Filter-Icons (PNG, light + white-Variante)
│   ├── logo.png             Site-Logo
│   ├── fonts.css            @font-face-Deklarationen (selbst-gehostet)
│   └── fonts/*.woff2        DM Sans + Playfair Display, latin subset
│
├── .design/                 Snapshots der jeweils letzten claude.ai/design-Exporte
│   └── *.html               (Referenz für Diff-basierte Re-Imports — nicht serviert)
│
├── tools/                   Pipeline-Skripte (siehe unten)
│
├── CNAME                    "adventuredogs.training" — von GitHub auto-verwaltet
├── .nojekyll                Schaltet Jekyll-Build aus (wir haben fertige HTML-Files)
├── robots.txt               Erlaubt Crawling, verweist auf Sitemap
└── sitemap.xml              6 URLs für Google/Bing-Crawler
```

---

## Pipeline-Skripte (in `tools/`)

### `resize-assets.ps1` (PowerShell)
Schrumpft JPEG-Bilder auf web-vernünftige Maße. Hero-Bilder max **2400 px** Breite,
andere max **1600 px**, JPEG-Qualität 82, EXIF gestrippt. **Idempotent** — bereits
passende Bilder bleiben unangetastet.

```bash
powershell -ExecutionPolicy Bypass -File tools/resize-assets.ps1 \
  -AssetsDir "C:/DATA/Claude/adventuredogs.training/assets"
```

### `sync-design-icons.sh`
Synchronisiert die 12 Filter-Icon-PNGs aus einem Design-Export ins Repo.
Diff-basiert — kopiert nur was sich geändert hat.

```bash
bash tools/sync-design-icons.sh /path/to/design-extract-vN
```

### `download-fonts.sh`
Lädt Google-Fonts-WOFF2-Dateien (DM Sans + Playfair Display, latin subset) lokal
nach `assets/fonts/`. Notwendig für GDPR-konformes Self-Hosting (LG München 2022).
Naming-Konvention passt zu dem was claude.ai/design's `fonts.css` erwartet.

```bash
bash tools/download-fonts.sh
```

### `post-import-fixes.sh`
**Wird nach jedem Re-Import automatisch aufgerufen.** Macht zwei Sachen die
claude.ai/design selbst nicht erledigt:

1. **Subpage-Pfad-Fix** für `<link href="assets/fonts.css">` — Subpages brauchen `../assets/fonts.css`
2. **SEO/OG/Twitter/JSON-LD-Injection** in den `<head>` jeder Seite (per-page meta description, canonical, og:tags, LocalBusiness-JSON-LD auf der Landing)

Bei Domain-Umzug: `SITE_BASE`-Variable im Skript ändern, einmal laufen lassen — alle
absoluten URLs flippen automatisch.

```bash
bash tools/post-import-fixes.sh
```

### `localbusiness-schema.json.html`
Das LocalBusiness-Schema-Snippet, das `post-import-fixes.sh` in die Landing einfügt.
Einzelne Datei damit man's als JSON reviewen kann statt als escaped Shell-String.

---

## Workflow: Re-Import nach Änderung in claude.ai/design

1. In claude.ai/design die Anpassungen machen
2. Bundle als ZIP herunterladen → liegt typischerweise in `~/Downloads/Adventure Dogs Training (N).zip`
3. ZIP entpacken in `C:/DATA/Claude/design-extract-vN/`
4. Per-Version-Skript `_rederive.sh` ausführen (kopiert HTMLs, macht URL-Substitutionen, Resize, Icons-Sync, Post-Import-Fixes)
5. `git add -A && git commit -m "Sync design vN — …" && git push`
6. GitHub Pages baut automatisch (~1-3 Min) — fertig.

Die Per-Version-`_rederive.sh`-Skripte werden bei jedem neuen Re-Import durch
Kopieren-und-Anpassen vom vorigen erstellt. Sie liegen außerhalb des Repos, in den
`design-extract-vN/`-Ordnern.

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

Bei Form-ID-Wechsel: in `kontakt/index.html` (oder direkt in claude.ai/design) ändern.

---

## Was Search Engines erfahren

- `robots.txt` erlaubt alles, verweist auf Sitemap.
- `sitemap.xml` listet alle 6 Seiten mit Prioritäten.
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
| Bilder oder Icons fehlen nach Re-Import | `_rederive.sh` evtl. Substitution für neuen Asset-Namen ergänzen. |
| Form-Mails kommen nicht an | Erste Formspree-Verifizierungs-Mail evtl. übersehen → Formspree-Dashboard prüfen. |
| Google indexiert eine Seite nicht | URL-Inspection in Search Console → „Live test" + „Indexierung beantragen". Kann 1-3 Tage dauern. |

---

## Lizenz

Privater Code für eine konkrete Webseite. Keine offizielle Lizenz hinterlegt —
nicht zur Wiederverwendung gedacht.
