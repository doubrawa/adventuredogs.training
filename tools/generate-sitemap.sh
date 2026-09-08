#!/bin/bash
# Regenerates sitemap.xml from tools/pages.tsv.
#
# Run it by hand before committing a content change, then commit the
# refreshed sitemap along with it — see README.md. tools/hooks/pre-commit
# ruft es ausserdem selbst auf.
#
# Die Seitenliste steht NICHT mehr hier, sondern in tools/pages.tsv —
# dieselbe Quelle, aus der auch generate-image-sitemap.ps1 und
# check-site.sh lesen. /gebucht/ und 404.html fehlen dort mit Absicht
# (beide noindex).
set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$DST/sitemap.xml"
PAGES="$DST/tools/pages.tsv"
BASE="https://adventuredogs.training"

[ -f "$PAGES" ] || { echo "FEHLER: $PAGES fehlt." >&2; exit 1; }

# In eine Tempdatei schreiben und erst am Ende ueberschreiben. Frueher hing
# die Umleitung direkt am Block: sitemap.xml wurde beim Betreten auf null
# gekuerzt und erst waehrend des Laufs gefuellt. Ein Abbruch dazwischen —
# set -e bei einem git-Fehler, volles Laufwerk, Strg-C — hinterliess ein
# abgeschnittenes XML ohne </urlset>, das der naechste `git add -A` brav
# mitgenommen haette.
TMP="$(mktemp)"
ERR="$TMP.err"
trap 'rm -f "$TMP" "$ERR"' EXIT

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
} > "$TMP"

# Kommentare und Leerzeilen raus, dann Zeile fuer Zeile.
grep -v '^[[:space:]]*#' "$PAGES" | grep -v '^[[:space:]]*$' | while IFS=$'\t' read -r url file freq prio mode _images; do
    [ -z "$url" ] && continue
    if [ ! -f "$DST/$file" ]; then
        # Frueher waere so eine Zeile stillschweigend als <loc> auf einen 404
        # gelandet. Lieber laut abbrechen.
        echo "FEHLER: $file aus pages.tsv existiert nicht." >&2
        echo x >> "$ERR"
        continue
    fi
    case "$mode" in
      anlage)
        # Fertige Artikel: lastmod = Erstelldatum (erstes git-Add), konsistent
        # mit dateModified im Article-Schema und stabil. Globale Aenderungen
        # (z.B. ein Logo-Swap im gemeinsamen Header) sollen es nicht anheben.
        lastmod=$(git -C "$DST" log --format=%cd --date=short --diff-filter=A -- "$file" 2>/dev/null | tail -1) ;;
      *)
        # Seiten, die sich real aendern: lastmod = letztes Commit-Datum.
        #
        # Ist die Datei gegenueber HEAD geaendert, zaehlt das heutige Datum:
        # das Skript laeuft vor dem Commit, die Aenderung steckt also noch
        # nicht in der Historie, und `git log` lieferte sonst hartnaeckig den
        # Stand der vorigen Runde.
        #
        # `diff HEAD` deckt Arbeitsverzeichnis UND Index ab, egal ob schon
        # `git add` gelaufen ist. Im frisch initialisierten Repo (noch kein
        # HEAD) scheitert es mit Exit 128 — dann greift ebenfalls heute, was
        # dort richtig ist. Beides steht in einer if-Bedingung, `set -e`
        # greift also nicht.
        if ! git -C "$DST" diff --quiet HEAD -- "$file" 2>/dev/null; then
          lastmod=$(date -u +%Y-%m-%d)
        else
          # `|| true`: bei einer unversionierten Datei liefert git log Exit 128
          # statt leerer Ausgabe — ohne das bricht `set -e` ab, bevor die
          # Rueckfallzeile unten zum Zug kommt.
          lastmod=$(git -C "$DST" log -1 --format=%cd --date=short -- "$file" 2>/dev/null || true)
        fi ;;
    esac
    [ -z "$lastmod" ] && lastmod=$(date -u +%Y-%m-%d)
    {
      echo "  <url>"
      echo "    <loc>${BASE}${url}</loc>"
      echo "    <lastmod>${lastmod}</lastmod>"
      echo "    <changefreq>${freq}</changefreq>"
      echo "    <priority>${prio}</priority>"
      echo "  </url>"
    } >> "$TMP"
done

echo '</urlset>' >> "$TMP"

# Die Schleife laeuft in einer Subshell (Pipeline), ihre Variablen sind hier
# nicht mehr sichtbar — deshalb der Umweg ueber die Fehlerdatei.
if [ -s "$ERR" ]; then
    echo "FEHLER: $(grep -c . "$ERR") Eintrag/Eintraege aus pages.tsv ohne Datei." >&2
    echo "        sitemap.xml wurde nicht angefasst." >&2
    exit 1
fi

anzahl=$(grep -c '<loc>' "$TMP" || true)
[ "$anzahl" -gt 0 ] || { echo "FEHLER: keine einzige URL erzeugt." >&2; exit 1; }

mv "$TMP" "$OUT"
echo "  sitemap.xml: $anzahl URLs, lastmod aus git"
