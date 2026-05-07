#!/bin/bash
# Re-applies persistent fixes after a fresh re-import from claude.ai/design.
#
# Run after _rederive.sh has finished its sed substitutions:
#
#   bash tools/post-import-fixes.sh
#
# Idempotent: each fix checks for the broken state before patching.
# Running on already-fixed files is a no-op.
#
# What's left here is INFRASTRUCTURE that doesn't really belong in a
# visual design tool: SEO meta tags + LocalBusiness structured data.
# Earlier rounds had a stack of Bug-N fixes for design-tool quirks
# (broken nav anchors, mobile crop, dead CSS, alt-texts, etc.) — those
# are now all fixed at the source in claude.ai/design and have been
# removed from this script. Git history has the full archaeology.

set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "post-import fixes against: $DST"

# ─── Favicon links (browser tab icon + iOS home-screen icon) ───
# claude.ai/design doesn't emit favicon links. We inject three variants:
#   - SVG icon for modern browsers (sharp at every size, vector)
#   - PNG icon as fallback for older browsers
#   - apple-touch-icon for iOS home-screen / Safari pinned tabs
# Path is "assets/" on Landing, "../assets/" on subpages.
inject_favicon() {
    local f="$1"
    local prefix="$2"   # "" for root, "../" for subpages
    if grep -q 'rel="icon"' "$f"; then return; fi   # already has one
    local block="<link rel=\"icon\" type=\"image/svg+xml\" href=\"${prefix}assets/logo.svg\">\n<link rel=\"icon\" type=\"image/png\" href=\"${prefix}assets/logo.png\">\n<link rel=\"apple-touch-icon\" href=\"${prefix}assets/logo.png\">"
    local D=$(printf '\035')
    sed -i "s${D}</title>${D}</title>\n${block}${D}" "$f"
    echo "  injected favicons: $f"
}
inject_favicon "$DST/index.html"               ""
inject_favicon "$DST/kontakt/index.html"       "../"
inject_favicon "$DST/angebot/index.html"       "../"
inject_favicon "$DST/alltagstipps/index.html"  "../"
inject_favicon "$DST/impressum/index.html"     "../"
inject_favicon "$DST/ueber-mich/index.html"    "../"

# ─── Subpage path fix for fonts.css ───
# claude.ai/design now emits <link href="assets/fonts.css"> on every
# page (good — uses our self-hosted fonts, no Google CDN call). But on
# subpages the path needs to be "../assets/fonts.css" instead, because
# the Pages structure is /kontakt/index.html etc. and "assets/..." would
# resolve to /kontakt/assets/... which doesn't exist.
# (The Landing index.html at root is fine — assets/fonts.css resolves
#  relative to / and hits the real file.)
for p in kontakt angebot alltagstipps impressum ueber-mich; do
    F="$DST/$p/index.html"
    if grep -q '<link href="assets/fonts.css" rel="stylesheet">' "$F"; then
        sed -i 's|<link href="assets/fonts.css" rel="stylesheet">|<link href="../assets/fonts.css" rel="stylesheet">|' "$F"
        echo "  fixed fonts.css path: $p"
    fi
done

# Belt-and-braces: bail loud if any page still pulls fonts from Google CDN.
if grep -lE 'fonts\.googleapis\.com|fonts\.gstatic\.com' "$DST"/index.html "$DST"/*/index.html 2>/dev/null > /dev/null; then
    echo "  WARN: some pages still reference Google Fonts CDN — design tool regressed?"
fi

# ─── SEO + OpenGraph + Twitter Card per page ───
# The design tool emits a bare head with just title/favicon/preconnect.
# We inject:
#   - <meta name="description"> (per page)
#   - <link rel="canonical">
#   - OpenGraph tags (og:type, og:title, og:description, og:url, og:image, og:site_name)
#   - Twitter Card type
# Sentinel: the canonical link, used for idempotency check.
#
# When the live site moves from doubrawa.github.io to adventuredogs.training,
# update SITE_BASE here, run the script, and all canonical+og:url+og:image
# absolute URLs flip in one go.
SITE_BASE="https://adventuredogs.training"

inject_seo() {
    local f="$1"
    local path="$2"     # "" for root, "kontakt/", "angebot/", etc.
    local title="$3"
    local desc="$4"
    local hero="$5"     # filename within /assets/

    if grep -q '<link rel="canonical"' "$f"; then return; fi  # already injected

    local url="$SITE_BASE/${path}"
    local img="$SITE_BASE/assets/${hero}"

    # Build the block. Insert right after the existing <title> line.
    # Description gets injected only if the page doesn't already have one
    # (Landing got one in earlier work; the design tool doesn't emit it).
    local has_desc=0
    grep -q '<meta name="description"' "$f" && has_desc=1

    local desc_line=""
    if [ "$has_desc" = "0" ]; then
        desc_line="<meta name=\"description\" content=\"${desc}\">\n"
    fi

    local block="${desc_line}<link rel=\"canonical\" href=\"${url}\">\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:site_name\" content=\"Adventure Dogs\">\n<meta property=\"og:title\" content=\"${title}\">\n<meta property=\"og:description\" content=\"${desc}\">\n<meta property=\"og:url\" content=\"${url}\">\n<meta property=\"og:image\" content=\"${img}\">\n<meta name=\"twitter:card\" content=\"summary_large_image\">"

    # Insert after the <title> closing tag.
    # Use ASCII GS (0x1d) as sed delimiter — won't ever appear in HTML/text/URLs.
    local D=$(printf '\035')
    sed -i "s${D}</title>${D}</title>\n${block}${D}" "$f"
    echo "  injected SEO/OG: $f"
}

# Per-page SEO content.
inject_seo "$DST/index.html" "" \
  "Adventure Dogs – Hundeschule Julia Doubrawa | Krumbach" \
  "Adventure Dogs – Hundeschule Julia Doubrawa in Krumbach. Welpenkurse, Einzeltraining, Sozialkontakt und besondere Events. Entspannt, individuell und mit Humor." \
  "hero-landing.jpg"

inject_seo "$DST/kontakt/index.html" "kontakt/" \
  "Kontakt – Adventure Dogs | Julia Doubrawa" \
  "Kontakt zur Hundeschule Adventure Dogs in Krumbach – Telefon, E-Mail, WhatsApp, Kontaktformular und FAQ. Schreib Julia Doubrawa direkt." \
  "hero-kontakt.jpg"

inject_seo "$DST/angebot/index.html" "angebot/" \
  "Angebot – Adventure Dogs | Hundeschule Julia Doubrawa Krumbach" \
  "Trainingsangebote der Hundeschule Adventure Dogs Krumbach: Welpenkurs, Basiskurs, Sozialkontakt, Trickdog, Jagdkontrolle, Einzeltraining und Quality-Time-Events." \
  "hero-angebot.jpg"

inject_seo "$DST/alltagstipps/index.html" "alltagstipps/" \
  "Alltagstipps – Adventure Dogs | Julia Doubrawa" \
  "Praktische Alltagstipps rund um Welpe, Silvester, Urlaub, Winter, Alleinbleiben, Tierphysiotherapie und Ernährung – aus der Hundeschule Adventure Dogs." \
  "hero-alltagstipps.jpg"

inject_seo "$DST/impressum/index.html" "impressum/" \
  "Impressum – Adventure Dogs | Julia Doubrawa" \
  "Impressum und Datenschutzerklärung der Hundeschule Adventure Dogs – Julia Doubrawa, Krumbach." \
  "hero-landing.jpg"

inject_seo "$DST/ueber-mich/index.html" "ueber-mich/" \
  "Über mich – Julia Doubrawa | Adventure Dogs Krumbach" \
  "Julia Doubrawa, Hundetrainerin aus Krumbach – mein Trainingsansatz, mein Weg mit Einstein und meine Fortbildungen rund um faires Hundetraining." \
  "hero-ueber-mich.jpg"

# ─── LocalBusiness JSON-LD on Landing ───
# Helps Google understand this is a Hundeschule in Krumbach with phone,
# address, service area. Supports Local-Search and Knowledge-Panel.
# Snippet lives in tools/localbusiness-schema.json.html as reviewable JSON.
F="$DST/index.html"
SCHEMA="$DST/tools/localbusiness-schema.json.html"
if ! grep -q '"@type": "LocalBusiness"' "$F"; then
    # Insert just after the meta name="description" line on Landing.
    desc_line=$(grep -n '<meta name="description"' "$F" | head -1 | cut -d: -f1)
    if [ -n "$desc_line" ]; then
        tmp=$(mktemp)
        head -n "$desc_line" "$F"          > "$tmp"
        cat "$SCHEMA"                      >> "$tmp"
        tail -n +$((desc_line + 1)) "$F"   >> "$tmp"
        mv "$tmp" "$F"
        echo "  injected LocalBusiness JSON-LD on Landing"
    fi
fi

echo "post-import fixes done."
