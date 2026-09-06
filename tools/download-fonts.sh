#!/bin/bash
# Download Google Fonts as woff2 files for self-hosting (GDPR-safe).
#
# Naming convention matches what claude.ai/design's emitted fonts.css
# expects (cleaner than the original Google hash-based filenames):
#   dm-sans-300.woff2  dm-sans-400.woff2  dm-sans-500.woff2  dm-sans-600.woff2
#   playfair-600.woff2 playfair-700.woff2 playfair-900.woff2
#   playfair-600-italic.woff2  playfair-700-italic.woff2
#   playfair-900-italic.woff2
#
# Subset: only `latin` (covers German + most Western European). The
# `latin-ext` subset would add Czech/Polish/Turkish glyphs we don't
# need. The single-file-per-weight approach matches what the design
# tool emits — no unicode-range splitting.
#
# Re-run anytime to refresh after Google version bumps.

set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONTS_DIR="$DST/assets/fonts"
mkdir -p "$FONTS_DIR"

# Eigene Zwischendatei statt eines festen /tmp-Pfads: sonst verarbeitet ein Lauf
# den Rest eines frueheren mit, und zwei parallele Laeufe schreiben uebereinander.
MAPPING="$(mktemp)"
trap 'rm -f "$MAPPING"' EXIT

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
# 1,900 gehoert dazu: das Akzentwort in den Hero-Zeilen und die Artikel-Initiale
# verlangen Playfair 900 kursiv. Fehlt der Schnitt, faellt der Browser stumm auf
# 700 kursiv zurueck und die Stelle steht zwei Gewichtsstufen zu leicht.
URL='https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,600;0,700;0,900;1,600;1,700;1,900&family=DM+Sans:wght@300;400;500;600&display=swap'
# Erwartete Zahl der Dateien — Abgleich am Ende, damit ein stilles Wegfallen
# einzelner Schnitte auffaellt statt unbemerkt zu bleiben.
ERWARTET=10

echo "Fetching Google Fonts CSS..."
# --fail: ohne das schreibt curl eine Fehlerseite als Erfolg durch.
RAW=$(curl -sSL --fail --max-time 15 -A "$UA" "$URL")

# Parse the CSS. Each @font-face block is preceded by a /* subset */
# comment. We want only the "latin" blocks, then per-block extract the
# font-family, font-weight, font-style, and woff2 URL.
echo "Parsing latin-subset @font-face blocks..."

# Split by /* ... */ comment markers, keep only blocks where comment == "latin"
parsed=$(echo "$RAW" | awk '
    BEGIN { keep = 0 }
    /^\/\* latin \*\/$/   { keep = 1; next }
    /^\/\* / { keep = 0; next }
    keep { print }
' )

# For each @font-face block, derive the canonical filename and download.
echo "$parsed" | awk '
    /font-family:/ { gsub(/[^A-Za-z]/, "", $0); fam = tolower(substr($0, length("fontfamily")+1)) }
    /font-style:/  { sub(/.*: */, ""); sub(/;$/, ""); style = $0 }
    /font-weight:/ { sub(/.*: */, ""); sub(/;$/, ""); weight = $0 }
    /url\(/ {
        match($0, /url\([^)]+\)/)
        url = substr($0, RSTART+4, RLENGTH-5)
        # canonical name
        short = (fam == "playfairdisplay") ? "playfair" : "dm-sans"
        suffix = (style == "italic") ? "-italic" : ""
        printf "%s-%s%s.woff2\t%s\n", short, weight, suffix, url
    }
' > "$MAPPING"

cat "$MAPPING"

# Ohne diese Pruefung endet ein Lauf, bei dem sich das CSS-Format geaendert hat
# (Kommentarzeile nicht mehr exakt "/* latin */", andere Reihenfolge), still mit
# "done." — und assets/fonts/ bleibt einfach auf dem alten Stand.
GEFUNDEN=$(grep -c . "$MAPPING" || true)
if [ "$GEFUNDEN" -ne "$ERWARTET" ]; then
    echo "FEHLER: $GEFUNDEN Schnitte im latin-Subset gefunden, erwartet $ERWARTET."
    echo "        Google hat vermutlich das CSS-Format geaendert — Parser pruefen."
    exit 1
fi

echo
echo "Downloading..."
while IFS=$'\t' read -r name url; do
    [ -z "$name" ] && continue
    dst="$FONTS_DIR/$name"
    tmp="$dst.part"
    # --fail statt stiller Erfolg: sonst landet eine HTML-Fehlerseite unveraendert
    # in der .woff2 und die Seite faellt im Browser auf Systemschriften zurueck.
    # Erst in .part laden und pruefen, damit ein Fehlschlag die bestehende Datei
    # nicht kaputtmacht.
    curl -sSL --fail --max-time 30 "$url" -o "$tmp"
    if [ "$(head -c 4 "$tmp")" != "wOF2" ]; then
        rm -f "$tmp"
        echo "FEHLER: $name ist keine WOFF2-Datei (falsche Magic Number)."
        exit 1
    fi
    mv "$tmp" "$dst"
    echo "  $name ($(stat -c%s "$dst") bytes)"
done < "$MAPPING"

echo "done."
