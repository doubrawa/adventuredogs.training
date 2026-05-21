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

# ─── Asset-name mapping: welpe-blau.png → offer-welpenkurs.jpg ───
# claude.ai/design started emitting "assets/welpe-blau.png" for the
# Welpenkurs card on Landing + Angebot (their internal upload of the
# blue-wood-wall puppy photo). We already have that same photo as
# the optimised assets/offer-welpenkurs.jpg (180 KB JPG vs 2.4 MB PNG).
# Rewrite the design's reference to our existing asset.
for f in "$DST/index.html" "$DST/angebot/index.html"; do
    if grep -q 'welpe-blau\.png' "$f"; then
        sed -i 's|welpe-blau\.png|offer-welpenkurs.jpg|g' "$f"
        echo "  rewrote welpe-blau.png → offer-welpenkurs.jpg: $(basename "$(dirname "$f")")/index.html"
    fi
done

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
[ -f "$DST/gebucht/index.html" ] && inject_favicon "$DST/gebucht/index.html" "../"
# Alltagstipps detail pages live 2 levels deep, so prefix is "../../".
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung; do
    [ -f "$DST/alltagstipps/$topic/index.html" ] && inject_favicon "$DST/alltagstipps/$topic/index.html" "../../"
done

# ─── Subpage path fix: any "assets/..." → "../assets/..." ───
# Subpages live at /<slug>/index.html, so a bare "assets/foo" resolves
# to /<slug>/assets/foo which 404s. They need "../assets/foo" instead.
# claude.ai/design occasionally emits the bare form (fonts.css link,
# new image refs in fresh sections, etc.). Generic fix: rewrite every
# src="assets/..." / href="assets/..." / url('assets/...') / url("assets/...")
# on the 5 subpages.
# Landing index.html at root is NOT touched — its assets/ refs are correct.
PATTERN='(src|href)="assets/|url\(['"'"'"]?assets/|url\(assets/'
for p in kontakt angebot alltagstipps impressum ueber-mich gebucht; do
    [ -f "$DST/$p/index.html" ] || continue
    F="$DST/$p/index.html"
    if grep -qE "$PATTERN" "$F" 2>/dev/null; then
        sed -i 's|src="assets/|src="../assets/|g'   "$F"
        sed -i 's|href="assets/|href="../assets/|g' "$F"
        sed -i "s|url('assets/|url('../assets/|g"   "$F"
        sed -i 's|url("assets/|url("../assets/|g'   "$F"
        sed -i 's|url(assets/|url(../assets/|g'     "$F"
        echo "  fixed subpage asset paths: $p"
    fi
done
# Same fix, two levels deep, for alltagstipps detail pages.
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung; do
    F="$DST/alltagstipps/$topic/index.html"
    [ -f "$F" ] || continue
    if grep -qE "$PATTERN" "$F" 2>/dev/null; then
        sed -i 's|src="assets/|src="../../assets/|g'   "$F"
        sed -i 's|href="assets/|href="../../assets/|g' "$F"
        sed -i "s|url('assets/|url('../../assets/|g"   "$F"
        sed -i 's|url("assets/|url("../../assets/|g'   "$F"
        sed -i 's|url(assets/|url(../../assets/|g'     "$F"
        echo "  fixed detail-page asset paths: alltagstipps/$topic"
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

# Alltagstipps detail pages — per-topic SEO. Hero image filename refers
# to whatever is in /assets/ today; if the topic-specific photo gets
# uploaded later, update the filename here too.
inject_seo "$DST/alltagstipps/welpenzeit/index.html" "alltagstipps/welpenzeit/" \
  "Welpenzeit gestalten – Alltagstipps | Adventure Dogs" \
  "Die ersten Wochen mit Welpe: Schlaf, Stubenreinheit, Bindung und Sozialisierung. Tipps von Hundetrainerin Julia Doubrawa aus Krumbach." \
  "offer-welpenkurs.jpg"

inject_seo "$DST/alltagstipps/silvester/index.html" "alltagstipps/silvester/" \
  "Silvester mit Hund – ohne Stress | Adventure Dogs" \
  "Silvester mit Hund entspannt überstehen: Vorbereitung, Rituale und Notfallstrategien gegen Stress durch Böller und Lichter." \
  "hero-silvester.jpg"

inject_seo "$DST/alltagstipps/urlaub/index.html" "alltagstipps/urlaub/" \
  "Mit Hund in den Urlaub – Reisetipps | Adventure Dogs" \
  "Mit Hund verreisen: Was du für Auto, Bahn, Flugzeug oder Ferienwohnung planen musst, damit alle entspannt ankommen." \
  "hero-urlaub.jpg"

inject_seo "$DST/alltagstipps/winter/index.html" "alltagstipps/winter/" \
  "Winter mit Hund – Pflege und Spaziergänge | Adventure Dogs" \
  "So kommt dein Hund gut durch den Winter: Pfotenpflege, Streusalz, kalte Tage und die richtigen Spaziergänge." \
  "hero-winter.jpg"

inject_seo "$DST/alltagstipps/alleinbleiben/index.html" "alltagstipps/alleinbleiben/" \
  "Alleinbleiben lernen – Schritt für Schritt | Adventure Dogs" \
  "So lernt dein Hund, dass Alleinsein okay ist — fairer und nachhaltiger Trainingsweg von Hundetrainerin Julia Doubrawa." \
  "service-einzeltraining.jpg"

inject_seo "$DST/alltagstipps/tierphysiotherapie/index.html" "alltagstipps/tierphysiotherapie/" \
  "Tierphysiotherapie für Hunde – wann sinnvoll? | Adventure Dogs" \
  "Wann eine Tierphysiotherapie für deinen Hund sinnvoll ist und woran du erkennst, dass dein Hund Hilfe braucht." \
  "offer-intensivcoaching.jpg"

inject_seo "$DST/alltagstipps/ernaehrung/index.html" "alltagstipps/ernaehrung/" \
  "Hundeernährung Grundlagen – Trocken, Nass, BARF | Adventure Dogs" \
  "Hundeernährung verstehen: Trockenfutter, Nassfutter, BARF und mehr. Ein Überblick über die Möglichkeiten und worauf es ankommt." \
  "partner-platinum.jpg"

# Gebucht (booking-confirmation page): inject SEO + noindex so Google
# doesn't index this post-conversion landing in search results.
if [ -f "$DST/gebucht/index.html" ]; then
    inject_seo "$DST/gebucht/index.html" "gebucht/" \
      "Buchung bestätigt – Adventure Dogs | Julia Doubrawa" \
      "Buchungsbestätigung der Hundeschule Adventure Dogs in Krumbach." \
      "strand.jpg"
    # Add robots: noindex,nofollow (idempotent)
    if ! grep -q '<meta name="robots"' "$DST/gebucht/index.html"; then
        D=$(printf '\035')
        sed -i "s${D}<link rel=\"canonical\"${D}<meta name=\"robots\" content=\"noindex,nofollow\">\n<link rel=\"canonical\"${D}" "$DST/gebucht/index.html"
        echo "  injected robots noindex: gebucht/index.html"
    fi
fi

# ─── Kontakt FAQ: 5 extra Q&A pairs for SEO ───
# claude.ai/design ships 5 FAQs on the Kontakt page (logistics-heavy:
# Wo, Wer, Antwortzeit, Erstanfrage, Formate). We extend with 5 questions
# people google BEFORE making contact: Kosten, Methode, Welpen-Alter,
# Problemverhalten, Trainerausbildung. Content lives in tools/faq-extra.html
# so the wording stays reviewable and editable in isolation.
# Idempotent: the "Was kostet das Training" sentinel ensures we only inject
# once. Anchor is the last existing FAQ ("Welche Trainingsformate ...").
# Also bump max-height on .faq-answer so the longer Methode answer
# doesn't clip on mobile.
F="$DST/kontakt/index.html"
if [ -f "$F" ] && ! grep -q 'Was kostet das Training' "$F"; then
    LAST_Q=$(grep -n 'Welche Trainingsformate bietest du an?' "$F" | head -1 | cut -d: -f1)
    if [ -n "$LAST_Q" ]; then
        # The closing </div> of that faq-item is 4 lines below the question.
        INSERT_LINE=$((LAST_Q + 4))
        tmp=$(mktemp)
        head -n "$INSERT_LINE" "$F"            > "$tmp"
        cat "$DST/tools/faq-extra.html"        >> "$tmp"
        tail -n +$((INSERT_LINE + 1)) "$F"     >> "$tmp"
        mv "$tmp" "$F"
        echo "  injected 5 extra FAQs on Kontakt"
    else
        echo "  WARN: FAQ anchor not found on Kontakt — extra FAQs not injected"
    fi
fi
# Bump max-height so the two-paragraph Methode answer doesn't clip on mobile.
if [ -f "$F" ] && grep -q '\.faq-item\.open \.faq-answer { max-height: 300px; }' "$F"; then
    sed -i 's|\.faq-item\.open \.faq-answer { max-height: 300px; }|.faq-item.open .faq-answer { max-height: 800px; }|g' "$F"
    echo "  bumped FAQ max-height: kontakt/index.html"
fi

# ─── FAQPage JSON-LD on Kontakt ───
# Schema.org FAQPage markup lets Google show our FAQ questions as
# expandable rich snippets directly in search results — major CTR boost.
# Static file mirrors the 10 Q&A pairs on /kontakt/. If FAQ wording
# changes upstream, update both kontakt/index.html (or faq-extra.html
# for our added 5) AND this JSON-LD file.
F="$DST/kontakt/index.html"
FAQ_SCHEMA="$DST/tools/faqpage-schema.json.html"
if [ -f "$F" ] && [ -f "$FAQ_SCHEMA" ] && ! grep -q '"@type": "FAQPage"' "$F"; then
    desc_line=$(grep -n '<meta name="description"' "$F" | head -1 | cut -d: -f1)
    if [ -n "$desc_line" ]; then
        tmp=$(mktemp)
        head -n "$desc_line" "$F"          > "$tmp"
        cat "$FAQ_SCHEMA"                  >> "$tmp"
        tail -n +$((desc_line + 1)) "$F"   >> "$tmp"
        mv "$tmp" "$F"
        echo "  injected FAQPage JSON-LD on Kontakt"
    fi
fi

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
