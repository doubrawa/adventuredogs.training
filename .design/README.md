# `.design/` — Upstream-Snapshot aus claude.ai/design

Dieser Ordner enthält die **rohe, unveränderte Version** des Designs, so wie es zuletzt aus claude.ai/design exportiert wurde. Die Datei hier wird **nicht** vom GitHub-Pages-Build verwendet — sie liegt nur als Referenz im Repo.

## Wozu?

Damit beim nächsten Update saubere Drei-Wege-Diffs möglich sind:

```
.design/Landing Page.html      ← was claude.ai/design beim letzten Mal ausgegeben hat (dieser Ordner)
neuer-export/Landing Page.html ← was claude.ai/design jetzt ausgibt (frisch heruntergeladen)
../index.html                  ← was im Repo lebt (mit Cleanups + ggf. Direkt-Änderungen)
```

Mit diesem Setup kann Claude beim nächsten Re-Import:

1. Den neuen Export gegen `.design/Landing Page.html` diffen → das sind **nur** deine Edits aus claude.ai/design.
2. Diese Deltas auf `../index.html` anwenden — ohne dass die Cleanups (lokale Asset-Pfade, kein Bundler-Scaffolding, relative Links) verloren gehen oder Direkt-Änderungen am Repo überschrieben werden.
3. Den frischen Export hier hinein kopieren, damit der Snapshot wieder aktuell ist.

## Bitte nicht manuell editieren

Diese Datei spiegelt **nur** den Output von claude.ai/design wider. Direkte Edits gehören in `../index.html` (oder, wenn sie aus claude.ai/design stammen, in den nächsten Re-Import).

## Update-Workflow

1. In claude.ai/design Anpassungen machen.
2. Bundle/Standalone-HTML herunterladen.
3. Claude den Pfad zum neuen Export geben → er kümmert sich um den Rest.

Am Ende eines Re-Imports laufen zwei Helper-Skripte automatisch (idempotent, also unbedenklich auch mehrmals):

- **`tools/resize-assets.ps1`** — schrumpft neu importierte Bilder auf web-vernünftige Maße (Heroes max 2400 px, sonst 1600 px Breite, JPEG q82, EXIF gestrippt). Verhindert dass volle DSLR-Auflösung ins Repo gerät.
- **`tools/post-import-fixes.sh`** — re-applied persistente Fixes, die **nicht** in claude.ai/design gemacht werden können bzw. dort nicht stabil sind:
  - Landing-Nav „Über mich" auf `ueber-mich/` statt auf den `#julia`-Anker setzen
  - Den 5 Angebot-Offer-Cards (Welpen / Erziehung / Sozialkontakt / Veranstaltungen / Einzeltraining) IDs zuweisen, damit die Service-Card-Anchor-Links von der Landing korrekt scrollen
  - Tote `.placeholder-box`-CSS-Regel im Impressum entfernen
  - SEO+OpenGraph+Twitter-Card-Block in den `<head>` jeder Seite injizieren (per-page description, canonical URL, og:image etc.)

Wenn die Domain mal von `doubrawa.github.io` auf `adventuredogs.training` umgezogen wird: in `tools/post-import-fixes.sh` einmal die `SITE_BASE`-Variable updaten und das Skript laufen lassen — alle absoluten URLs (canonical, og:url, og:image) flippen in einem Rutsch. `robots.txt` und `sitemap.xml` müssen separat angepasst werden.
