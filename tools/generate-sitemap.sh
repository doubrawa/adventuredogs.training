#!/bin/bash
# Regenerates sitemap.xml with lastmod derived from each page's last
# git commit. Keeps priorities/changefreq as a static policy table.
# Runs at the end of post-import-fixes.sh — sitemap dates can never
# go stale again.
#
# Note: /gebucht/ is deliberately absent (noindex page).
set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$DST/sitemap.xml"
BASE="https://adventuredogs.training"

# url-path | file | changefreq | priority
TABLE="
/|index.html|monthly|1.0
/angebot/|angebot/index.html|monthly|0.9
/ueber-mich/|ueber-mich/index.html|monthly|0.8
/alltagstipps/|alltagstipps/index.html|monthly|0.8
/alltagstipps/welpenzeit/|alltagstipps/welpenzeit/index.html|monthly|0.7
/alltagstipps/silvester/|alltagstipps/silvester/index.html|monthly|0.7
/alltagstipps/urlaub/|alltagstipps/urlaub/index.html|monthly|0.7
/alltagstipps/winter/|alltagstipps/winter/index.html|monthly|0.7
/alltagstipps/alleinbleiben/|alltagstipps/alleinbleiben/index.html|monthly|0.7
/alltagstipps/tierphysiotherapie/|alltagstipps/tierphysiotherapie/index.html|monthly|0.7
/alltagstipps/ernaehrung/|alltagstipps/ernaehrung/index.html|monthly|0.7
/alltagstipps/hund-entlaufen/|alltagstipps/hund-entlaufen/index.html|monthly|0.7
/kontakt/|kontakt/index.html|monthly|0.7
/impressum/|impressum/index.html|yearly|0.3
"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo "$TABLE" | while IFS='|' read -r url file freq prio; do
    [ -z "$url" ] && continue
    case "$file" in
      alltagstipps/*/index.html)
        # Fertige Artikel-Detailseiten: lastmod = Erstelldatum (erstes
        # git-Add), konsistent mit dateModified im Article-Schema und
        # stabil. Globale Änderungen (z.B. Logo-Swap im gemeinsamen Header)
        # sollen die Artikel-lastmod NICHT hochbumpen.
        lastmod=$(git -C "$DST" log --format=%cd --date=short --diff-filter=A -- "$file" 2>/dev/null | tail -1) ;;
      *)
        # Dynamische Seiten (Start, Angebot, Kontakt, Hub, …): lastmod =
        # letztes Commit-Datum, die ändern sich real über die Zeit.
        lastmod=$(git -C "$DST" log -1 --format=%cd --date=short -- "$file" 2>/dev/null) ;;
    esac
    [ -z "$lastmod" ] && lastmod=$(date -u +%Y-%m-%d)
    echo "  <url>"
    echo "    <loc>${BASE}${url}</loc>"
    echo "    <lastmod>${lastmod}</lastmod>"
    echo "    <changefreq>${freq}</changefreq>"
    echo "    <priority>${prio}</priority>"
    echo "  </url>"
  done
  echo '</urlset>'
} > "$OUT"

echo "  sitemap.xml regenerated ($(grep -c '<loc>' "$OUT") URLs, lastmod aus git)"
