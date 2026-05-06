#!/bin/bash
# Download Google Fonts to local assets/fonts/ directory and generate
# a self-hostable assets/fonts.css.
#
# Why: embedding Google Fonts via fonts.googleapis.com transmits the
# visitor's IP to Google in the US, which is a GDPR violation in the
# EU (LG München, Az. 3 O 17493/20, Jan 2022). Self-hosting eliminates
# the third-party request → no IP transfer → no Abmahn-grounds.
#
# What this fetches:
#   Playfair Display 600 / 700 / 900 / 600italic / 700italic
#   DM Sans          300 / 400 / 500 / 600
#   Subsets: latin + latin-ext only (covers German + most Western
#   European scripts; cyrillic + vietnamese dropped to save bytes)
#
# Output:
#   assets/fonts/*.woff2  — actual font files
#   assets/fonts.css      — @font-face declarations referencing them
#
# Re-run safely if Google bumps font versions — overwrites cleanly.

set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONTS_DIR="$DST/assets/fonts"
CSS_FILE="$DST/assets/fonts.css"
mkdir -p "$FONTS_DIR"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
URL='https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,600;0,700;0,900;1,600;1,700&family=DM+Sans:wght@300;400;500;600&display=swap'

echo "Fetching Google Fonts CSS..."
RAW=$(curl -sL --max-time 15 -A "$UA" "$URL")

# Parse CSS: keep only the latin and latin-ext blocks (a "block" is
# a /* subset */ comment + the @font-face that follows). Drop cyrillic
# and vietnamese.
echo "Filtering to latin / latin-ext subsets..."
FILTERED=$(echo "$RAW" | awk '
    BEGIN { keep=0; buf="" }
    /^\/\* (latin|latin-ext) \*\// { keep=1; print; next }
    /^\/\* / { keep=0; next }
    keep { print }
')

# Extract unique woff2 URLs from the filtered CSS
URLS=$(echo "$FILTERED" | grep -oE 'https://fonts\.gstatic\.com/[^)]+\.woff2' | sort -u)
COUNT=$(echo "$URLS" | wc -l)
echo "Downloading $COUNT woff2 files..."

# Download each woff2, naming by its basename
for url in $URLS; do
    name=$(basename "$url")
    dst="$FONTS_DIR/$name"
    if [ -f "$dst" ]; then
        echo "  skip (exists): $name"
    else
        curl -sL --max-time 30 "$url" -o "$dst"
        echo "  fetched: $name ($(stat -c%s "$dst") bytes)"
    fi
done

# Rewrite URLs in the CSS to point at our local copies
echo "Generating $CSS_FILE..."
echo "$FILTERED" | sed 's|https://fonts\.gstatic\.com/[^)]*/\([^)]*\.woff2\)|fonts/\1|g' > "$CSS_FILE"
wc -l "$CSS_FILE"

echo "done."
