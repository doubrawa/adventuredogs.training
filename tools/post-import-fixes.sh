#!/bin/bash
# Re-applies persistent fixes after a fresh re-import from claude.ai/design.
#
# These are bugs/quirks in the design-tool output that we don't want
# claude.ai/design to control — they should always end up the same way
# in the deployed site, regardless of what the design tool emits.
#
# Run after _rederive.sh has finished its sed substitutions:
#
#   bash tools/post-import-fixes.sh
#
# Idempotent: each fix checks for the broken state before patching.
# Running on already-fixed files is a no-op.

set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "post-import fixes against: $DST"

# ─── Bug 0: Mein-Versprechen photo on Landing ───
# Design tool emits assets/julia-portrait.jpg for the .julia-photo slot
# (the original portrait we used early on). We replaced that asset with
# julia-einstein-kuss.jpg locally; the design tool isn't aware of the swap.
# So every fresh re-import would restore the broken reference.
F="$DST/index.html"
if grep -q "url('assets/julia-portrait\.jpg')" "$F"; then
    sed -i "s|url('assets/julia-portrait\.jpg')|url('assets/julia-einstein-kuss.jpg')|g" "$F"
    echo "  fixed: Landing Mein-Versprechen photo (julia-portrait.jpg → julia-einstein-kuss.jpg)"
fi

# ─── Bug 1: Landing nav 'Über mich' must point to subpage, not anchor ───
# Design tool emits href="#julia" because the Mein-Versprechen section
# on Landing has id="julia" (legacy from before there was a Über-mich
# subpage). All other pages link to ../ueber-mich/. We want consistency.
F="$DST/index.html"
if grep -q '<li><a href="#julia">Über mich</a></li>' "$F"; then
    sed -i 's|<li><a href="#julia">Über mich</a></li>|<li><a href="ueber-mich/">Über mich</a></li>|' "$F"
    echo "  fixed: Landing nav Über mich (#julia → ueber-mich/)"
fi

# ─── Bug 2: Landing service-cards filter the Angebot page on click ───
#
# The design emits hrefs like "angebot/#welpen", "angebot/#sozialkontakt",
# etc. on the 5 Landing service cards. Those anchors don't exist on the
# Angebot page (they got removed when the filter UX was reorganised in
# v5), so the click just lands at the top of the page.
#
# Better UX than restoring anchors: rewrite each href to ?cat=<filter>
# so the Angebot page lands with the matching filter pre-applied. Pair
# this with a small <script> on Angebot that reads ?cat= and clicks the
# matching filter button.
#
# Mapping (Landing card  →  Angebot filter category):
#   #welpen           Welpenkurs / "Der perfekte Start"      → erziehung
#   #sozialkontakt    "Entspannte Hundebegegnungen"          → begegnung
#   #veranstaltungen  Quality Time & Events                  → events
#   #erziehung        Basiskurs / "Gemeinsam starten"        → erziehung
#   #einzel           Einzeltraining / "Individuelle Lösung" → problem
F="$DST/index.html"
sed -i 's|href="angebot/#welpen"|href="angebot/?cat=erziehung"|g'        "$F"
sed -i 's|href="angebot/#sozialkontakt"|href="angebot/?cat=begegnung"|g' "$F"
sed -i 's|href="angebot/#veranstaltungen"|href="angebot/?cat=events"|g'  "$F"
sed -i 's|href="angebot/#erziehung"|href="angebot/?cat=erziehung"|g'     "$F"
sed -i 's|href="angebot/#einzel"|href="angebot/?cat=problem"|g'          "$F"

# Counterpart: inject filter-from-URL <script> on Angebot.
# Snippet lives in tools/angebot-filter-from-url.html (versioned in the
# repo so the JS itself is reviewable as JS, not as escaped string).
# Sentinel: the unique comment "Auto-apply filter when arriving via ?cat="
# used for idempotency.
F="$DST/angebot/index.html"
SNIPPET="$DST/tools/angebot-filter-from-url.html"
if ! grep -q 'Auto-apply filter when arriving via ?cat=' "$F"; then
    # Locate the existing "<script> / // Mobile nav" block and splice our
    # snippet in just before it. Done in two cuts (head + snippet + tail)
    # rather than wrestling with sed quoting for the JS body.
    mobile_line=$(grep -n '^  // Mobile nav$' "$F" | head -1 | cut -d: -f1)
    if [ -n "$mobile_line" ]; then
        # find <script> on a line before mobile_line
        script_line=$(awk -v ln="$mobile_line" 'NR<ln && /^<script>$/{last=NR} END{print last}' "$F")
        if [ -n "$script_line" ]; then
            # Insert snippet content before that <script> line.
            # Strategy: split file at script_line - 1, splice in snippet.
            tmp=$(mktemp)
            head -n $((script_line - 1)) "$F" > "$tmp"
            cat "$SNIPPET"                 >> "$tmp"
            tail -n +$script_line "$F"     >> "$tmp"
            mv "$tmp" "$F"
            echo "  fixed: Angebot filter-from-URL script injected"
        else
            echo "  WARN: could not find <script> anchor before Mobile nav"
        fi
    else
        echo "  WARN: could not find Mobile nav anchor in Angebot"
    fi
fi

# ─── Bug 3: Highlight offer-cards crop their image on mobile ───
# The design's mobile media query forces the image container to a fixed
# 220px height while the inner <img> inherits the desktop rule
# `height: 100%; object-fit: cover` — so the image gets brutally
# cropped on phones. Regular (non-highlight) offer-cards don't do this:
# their .offer-img has no fixed height and the image flows at natural
# aspect ratio. We want the highlight cards to behave the same on mobile.
F="$DST/angebot/index.html"
if grep -q '\.offer-card\.highlight \.offer-img { width: 100%; height: 220px; }' "$F"; then
    # Replace the broken rule with two rules: height auto on container,
    # height auto + object-fit contain on the inner img to override the
    # cover crop from the desktop styles.
    perl -i -pe 's|^(    )\.offer-card\.highlight \.offer-img \{ width: 100%; height: 220px; \}$|$1.offer-card.highlight .offer-img { width: 100%; height: auto; }\n$1.offer-card.highlight .offer-img img { height: auto; object-fit: contain; }|' "$F"
    echo "  fixed: Angebot highlight-card mobile image (no more 220px crop)"
fi

# ─── Bug 4: Über mich mobile hero anchors text at top ───
# Design's mobile @media block on Über mich sets align-items: flex-start
# with padding-top: 100px — that pins the headline to the top of the
# hero. Every other page (and Über mich's own desktop hero) anchors
# the text at the BOTTOM of the photo with align-items: flex-end and
# only a padding-bottom. We want consistency across pages.
F="$DST/ueber-mich/index.html"
if grep -q '\.hero { height: 60vh; min-height: 420px; max-height: 520px; align-items: flex-start; padding-top: 100px; padding-bottom: 40px; }' "$F"; then
    sed -i 's|\.hero { height: 60vh; min-height: 420px; max-height: 520px; align-items: flex-start; padding-top: 100px; padding-bottom: 40px; }|\.hero { height: 60vh; min-height: 420px; max-height: 520px; padding-bottom: 40px; }|' "$F"
    echo "  fixed: Über mich mobile hero anchors text at bottom"
fi

# ─── Cleanup: dead .placeholder-box CSS in Impressum ───
# That class was only used by the two boxes the design tool replaced
# with real content. The CSS rules are still emitted but never applied.
F="$DST/impressum/index.html"
if grep -q '\.placeholder-box {' "$F"; then
    # Delete the 3 CSS rules in one swoop (3 lines of placeholder-box rules)
    sed -i '/  \.placeholder-box {$/,/^  \.placeholder-box p { font-size: 13px; color: var(--text-lt); margin: 0; }$/d' "$F"
    echo "  fixed: Impressum dead .placeholder-box CSS removed"
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
SITE_BASE="https://doubrawa.github.io/adventuredogs.training"

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

# ─── Alt-texts on Angebot offer-card images ───
# The design emits empty alt="" on every offer-card <img>. For SEO and
# accessibility we want descriptive alt-texts. Keyed by image filename.
F="$DST/angebot/index.html"
declare -A alt_texts=(
    [offer-welpenkurs.jpg]="Welpe im Welpenkurs der Hundeschule Adventure Dogs Krumbach"
    [offer-basis.jpg]="Hund im Basiskurs lernt entspanntes Laufen an der Leine"
    [offer-jagdkontrolle.jpg]="Hund beim Jagdkontroll-Training im Wald"
    [service-sozialkontakt.jpg]="Hunde-Sozialkontakt-Training in kleiner Gruppe"
    [offer-social-walk.jpg]="Geführter Social Walk – Spaziergang mit mehreren Hunden"
    [offer-training-events.jpg]="Trainingsveranstaltung im Alltag der Hundeschule Adventure Dogs"
    [offer-quality-time.jpg]="Quality-Time-Event mit Hund"
    [offer-trickdog.jpg]="Hund beim Trickdog-Training"
    [service-einzeltraining.jpg]="Einzeltraining mit Julia Doubrawa und Hund"
    [offer-intensivcoaching.jpg]="Intensivcoaching für Hunde mit Problemverhalten"
)
patched_alts=0
for img in "${!alt_texts[@]}"; do
    txt="${alt_texts[$img]}"
    # Idempotency: only patch if the alt is currently empty for this img
    if grep -q "src=\"\\.\\./assets/${img//./\\.}\" alt=\"\"" "$F"; then
        sed -i "s|src=\"\\.\\./assets/${img//./\\.}\" alt=\"\"|src=\"../assets/${img}\" alt=\"${txt}\"|" "$F"
        patched_alts=$((patched_alts+1))
    fi
done
[ "$patched_alts" -gt 0 ] && echo "  alt-texts patched on Angebot ($patched_alts)"

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
