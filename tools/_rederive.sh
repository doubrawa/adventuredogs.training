#!/bin/bash
# Import-Pipeline für claude.ai/design-Exporte (Master-Kopie).
#
# Workflow pro neuem Export "Adventure Dogs Training (N).zip":
#   1. mkdir C:/DATA/Claude/design-extract-vN && dort entpacken
#   2. Dieses Script dorthin kopieren, SRC auf design-extract-vN setzen
#   3. bash _rederive.sh   (ruft am Ende resize-assets + post-import-fixes)
#   4. Diff prüfen, committen — und Änderungen an der Kopie hierher
#      zurückspiegeln, damit die Master-Kopie aktuell bleibt.
#
# Historie: die per-Version-Kopien in design-extract-v2 … v44 wurden
# Juli 2026 gelöscht (3,4 GB); Evolution der Patches steht in der
# git-History dieser Datei bzw. vorher in den Commit-Messages.
set -e
SRC="C:/DATA/Claude/design-extract-v47"
DST="C:/DATA/Claude/adventuredogs.training"

clean_page() {
  local f="$1"
  local p="$2"
  # back = path back to root, used for the Landing-page self-link.
  #   root (p="")        → "./"
  #   1-level (p="../")  → "../"
  #   2-level (p="../../") → "../../"
  local back="${p:-./}"
  # Logo URL from WordPress upload — same on every page
  sed -i "s|https://adventuredogs.training/wp-content/uploads/2025/05/logo-80x80\.png|${p}assets/logo.png|g" "$f"
  # The design tool emits sibling links in different forms depending on
  # the source file's own depth in its export tree:
  #   - Bare ("Landing Page.html") from flat root pages
  #   - 1-level prefix ("../Landing Page.html") from gebucht/index.html
  #   - 2-level prefix ("../../Landing Page.html") from alltagstipps/<topic>/index.html
  # The (\.\./)* group matches any number of ../ prefixes uniformly so the
  # same substitution works for all three cases.
  sed -i "s|\"\(\.\./\)*Landing Page\.html\"|\"${back}\"|g" "$f"
  sed -i "s|\"\(\.\./\)*Angebotsseite\.html#|\"${p}angebot/#|g" "$f"
  sed -i "s|\"\(\.\./\)*Angebotsseite\.html?|\"${p}angebot/?|g" "$f"
  sed -i "s|\"\(\.\./\)*Angebotsseite\.html\"|\"${p}angebot/\"|g" "$f"
  sed -i "s|\"\(\.\./\)*Alltagstipps\.html\"|\"${p}alltagstipps/\"|g" "$f"
  sed -i "s|\"\(\.\./\)*Kontakt\.html\"|\"${p}kontakt/\"|g" "$f"
  sed -i "s|\"\(\.\./\)*Impressum\.html#|\"${p}impressum/#|g" "$f"
  sed -i "s|\"\(\.\./\)*Impressum\.html\"|\"${p}impressum/\"|g" "$f"
  sed -i 's|"\(\.\./\)*Über mich\.html"|"'"${p}"'ueber-mich/"|g' "$f"
  # Absolute production URLs occasionally slip into the design output
  sed -i "s|https://adventuredogs.training/kontakt/|${p}kontakt/|g" "$f"
  sed -i "s|https://adventuredogs.training/alltagstipps/|${p}alltagstipps/|g" "$f"
  sed -i "s|https://adventuredogs.training/angebot/|${p}angebot/|g" "$f"
  sed -i "s|https://adventuredogs.training/impressum/|${p}impressum/|g" "$f"
  sed -i "s|https://adventuredogs.training/julia/|${p}ueber-mich/|g" "$f"
}

inject_head() {
  # Historically used to bolt on icon + Google-Fonts preconnect lines.
  # Since v21 the design tool ships local fonts and post-import-fixes.sh
  # injects favicons after </title>, so this is now a no-op kept for
  # backwards compatibility with earlier callers.
  return 0
}

strip_landing_scaffolding() {
  local f="$1"
  sed -i '/<meta name="ext-resource-dependency"/d' "$f"
  sed -i '/<template id="__bundler_thumbnail"/,/<\/template>/d' "$f"
  sed -i 's| data-res-id="logoImg"||g' "$f"
  sed -i '/\/\/ Apply ext-resource-dependency images/,/else applyResources();/d' "$f"
  sed -i "/\/\/ Tweaks$/,/__edit_mode_available' }, '\*');/d" "$f"
}

rewrite_offer_img() {
  local f="$1"
  local p="$2"
  local rel="$3"
  local target="$4"
  sed -i "s|url('https://adventuredogs.training/wp-content/uploads/${rel//./\\.}')|url('${p}assets/${target}')|g" "$f"
  sed -i "s|src=\"https://adventuredogs.training/wp-content/uploads/${rel//./\\.}\"|src=\"${p}assets/${target}\"|g" "$f"
}

# ── LANDING PAGE ──
F="$DST/index.html"
cp "$SRC/Landing Page.html" "$F"
clean_page "$F" ""
sed -i "s|url('uploads/_DSC2174\.jpg')|url('assets/hero-landing.jpg')|g" "$F"
rewrite_offer_img "$F" "" "2025/05/hunde.jpg"        "service-welpenkurs.jpg"
rewrite_offer_img "$F" "" "2025/05/einzel.jpg"       "service-einzeltraining.jpg"
rewrite_offer_img "$F" "" "2025/05/quality.jpg"      "service-events.jpg"
rewrite_offer_img "$F" "" "2025/08/sozialkontakt.jpg" "service-sozialkontakt.jpg"
strip_landing_scaffolding "$F"
echo "OK index.html"

# ── KONTAKT ──
F="$DST/kontakt/index.html"
cp "$SRC/Kontakt.html" "$F"
clean_page "$F" "../"
sed -i "s|url('assets/kontakt-hero\.jpg')|url('../assets/hero-kontakt.jpg')|g" "$F"
sed -i "s|url('uploads/_DSC1904-788a8fba\.jpg')|url('../assets/hero-kontakt.jpg')|g" "$F"
sed -i 's|formspree.io/f/DEINE_FORMSPREE_ID|formspree.io/f/xaqvnvzq|' "$F"
echo "OK kontakt/index.html"

# ── ANGEBOT ──
F="$DST/angebot/index.html"
cp "$SRC/Angebotsseite.html" "$F"
clean_page "$F" "../"
sed -i "s|url('assets/hero-gipfel\.jpg')|url('../assets/hero-angebot.jpg')|g" "$F"
sed -i 's|src="assets/icon-|src="../assets/icon-|g' "$F"
rewrite_offer_img "$F" "../" "2025/05/welpen.jpg"                  "offer-welpenkurs.jpg"
rewrite_offer_img "$F" "../" "2025/05/basis.jpg"                   "offer-basis.jpg"
rewrite_offer_img "$F" "../" "2025/05/einzel.jpg"                  "service-einzeltraining.jpg"
rewrite_offer_img "$F" "../" "2025/05/veranstaltungen.jpg"         "offer-quality-time.jpg"
rewrite_offer_img "$F" "../" "2025/06/veranstaltungentraining.jpg" "offer-training-events.jpg"
rewrite_offer_img "$F" "../" "2025/08/sozialkontakt.jpg"           "service-sozialkontakt.jpg"
rewrite_offer_img "$F" "../" "2026/01/Sozialwalk.jpeg"             "offer-social-walk.jpg"
rewrite_offer_img "$F" "../" "2026/01/trickdog.jpeg"               "offer-trickdog.jpg"
rewrite_offer_img "$F" "../" "2026/04/jagd_quadratisch.jpg"        "offer-jagdkontrolle.jpg"
sed -i "s|src=\"assets/intensivcoaching\.jpg\"|src=\"../assets/offer-intensivcoaching.jpg\"|g" "$F"
echo "OK angebot/index.html"

# ── ALLTAGSTIPPS HUB ──
# Hub page replaces the old long-form Alltagstipps page. Card links from
# the design tool come as "alltagstipps/welpenzeit/" (relative to its own
# source location in root). On the live site at /alltagstipps/index.html
# that resolves to /alltagstipps/alltagstipps/welpenzeit/ → 404.
# Strip the "alltagstipps/" prefix so cards become "welpenzeit/" etc.
F="$DST/alltagstipps/index.html"
cp "$SRC/Alltagstipps.html" "$F"
clean_page "$F" "../"
sed -i "s|url('uploads/_DSC1849-cbf18beb\.jpg')|url('../assets/hero-alltagstipps.jpg')|g" "$F"
# Fix card link prefix (only affects the 7 topic-card hrefs)
sed -i 's|href="alltagstipps/|href="|g' "$F"
echo "OK alltagstipps/index.html (hub)"

# ── ALLTAGSTIPPS DETAIL PAGES (7 articles) ──
# Each detail page lives 2 levels deep at /alltagstipps/<topic>/index.html.
# clean_page handles the ../../-prefixed links via the (\.\./)* pattern.
# Asset-name mismatches: the design tool references some images that
# don't exist in our /assets/ folder. We rewrite them here to existing
# fallbacks. Replace with proper photos in a future pass by updating
# /assets/ and removing these rewrites.
process_detail() {
  local topic="$1"
  local hero_target="$2"     # asset filename for the topic hero
  local design_hero="$3"     # what the design tool calls it (basename only)
  mkdir -p "$DST/alltagstipps/$topic"
  local F="$DST/alltagstipps/$topic/index.html"
  cp "$SRC/alltagstipps/$topic/index.html" "$F"
  clean_page "$F" "../../"
  # Hero background
  sed -i "s|url('\.\./\.\./assets/${design_hero//./\\.}')|url('../../assets/${hero_target}')|g" "$F"
  # Julia portrait — only one Julia portrait exists in /assets/
  sed -i "s|src=\"\.\./\.\./assets/julia-portrait\.jpg\"|src=\"../../assets/julia-einstein-kuss.jpg\"|g" "$F"
  # Empfehlungs-/Partner-Bilder: das Design-Tool legt sie als bare
  # Filenames neben das HTML (relativ zur Detail-Seite). Wir wollen
  # sie zentral in /assets/, also Pfade auf ../../assets/ rewriten.
  # Match wirkt nur auf der jeweils zutreffenden Detail-Seite, bei
  # den anderen ein No-op.
  sed -i 's|src="lena-hillenbrand-logo\.png"|src="../../assets/lena-hillenbrand-logo.png"|g' "$F"
  sed -i 's|src="platinum\.jpg"|src="../../assets/platinum.jpg"|g' "$F"
  # Nav-Logo vereinheitlichen: manche Exporte referenzieren logo-nav.svg
  # (unoptimierte 204-KB-Kopie desselben runden Logos). Auf das bereits
  # optimierte logo.svg umbiegen — konsistent mit allen anderen Seiten.
  sed -i 's|assets/logo-nav\.svg|assets/logo.svg|g' "$F"
  echo "OK alltagstipps/$topic/index.html"
}

# Topic | hero target (existing asset) | design-tool name
process_detail "welpenzeit"        "offer-welpenkurs.jpg"      "offer-welpenkurs.jpg"
process_detail "silvester"         "hero-silvester.jpg"        "julia-nebel-felsen.jpg"
process_detail "urlaub"            "hero-urlaub.jpg"           "hero-gipfel.jpg"
process_detail "winter"            "hero-winter.jpg"           "julia-nebel-felsen.jpg"
process_detail "alleinbleiben"     "hero-alleinbleiben.jpg"    "julia-einstein-wiese.jpg"
process_detail "tierphysiotherapie" "hero-tierphysiotherapie.jpg" "intensivcoaching.jpg"
process_detail "ernaehrung"        "hero-ernaehrung.jpg"       "julia-coffee-dogs.jpg"

# ── hund-entlaufen (Notfall-Artikel, Sonderfälle) ──
# clean_page + logo-nav-Fix laufen über process_detail; design_hero ist
# hier ein Dummy, weil die Seite (noch) kein Hero-FOTO hat, sondern einen
# Gradient-Platzhalter.
process_detail "hund-entlaufen"    "hero-hund-entlaufen.jpg"   "__kein-hero-foto__"
F="$DST/alltagstipps/hund-entlaufen/index.html"
# Hero: Gradient-Platzhalter durch Foto ersetzen. hero-hund-entlaufen.jpg
# ist aktuell eine Interim-Kopie von hero-alltagstipps.jpg — sobald Julia
# in claude.ai/design ein echtes "suchender Hund"-Foto liefert, wird nur
# diese eine Datei überschrieben, ohne Mapping-Änderung.
perl -0777 -pi -e "s#\.hero-bg\s*\{[^}]*repeating-linear-gradient[^}]*\}#.hero-bg { position: absolute; inset: 0; background: url('../../assets/hero-hund-entlaufen.jpg') center 40% / cover no-repeat; }#s" "$F"
# Sichtbaren Hero-Platzhalter-Tag ("[ HERO-FOTO — wird ausgetauscht ]")
# entfernen — sobald ein echtes Foto liegt, ist er ohnehin überflüssig.
sed -i 's#<span class="hero-placeholder-tag">[^<]*</span>##g' "$F"
# TASSO-Platzhalter (inkl. <mark class="ph">-Highlight-Wrapper) durch die
# offizielle Notruf-Nummer ersetzen (vom Betreiber im Original-Text so
# angegeben). Wrapper mit weg, sonst zeigt die Nummer gelb hervorgehoben.
sed -i 's#<mark class="ph">\[Julia:[^]]*\]</mark>#06190 937300#g' "$F"
# Sicherheitsnetz: sollten weitere <mark class="ph">…</mark>-Platzhalter
# übrig sein (z.B. das Aktualisiert-Datum füllt post-import-fixes), den
# Highlight-Wrapper entfernen, damit auf der Live-Seite nichts gelb
# markiert erscheint — Inhalt bleibt erhalten.
sed -i 's#<mark class="ph">\([^<]*\)</mark>#\1#g' "$F"
echo "OK alltagstipps/hund-entlaufen (Sonderfixes: Hero-Foto, TASSO-Nummer)"

# ── IMPRESSUM ──
F="$DST/impressum/index.html"
cp "$SRC/Impressum.html" "$F"
clean_page "$F" "../"
echo "OK impressum/index.html"

# ── ÜBER MICH ──
F="$DST/ueber-mich/index.html"
cp "$SRC/Über mich.html" "$F"
clean_page "$F" "../"
sed -i "s|url('uploads/aboutme\.jpg')|url('../assets/hero-ueber-mich.jpg')|g" "$F"
sed -i "s|url('uploads/235A1434\.JPG')|url('../assets/ueber-mich-story.jpg')|g" "$F"
sed -i "s|url('uploads/_DSC2148\.jpg')|url('../assets/ueber-mich-vision.jpg')|g" "$F"
sed -i 's|src="assets/julia-portrait-holz\.jpg"|src="../assets/julia-portrait-holz.jpg"|g' "$F"
sed -i 's|src="assets/einstein-wasser\.jpg"|src="../assets/einstein-wasser.jpg"|g' "$F"
echo "OK ueber-mich/index.html"

# ── GEBUCHT (Buchungsbestätigung) ──
mkdir -p "$DST/gebucht"
F="$DST/gebucht/index.html"
cp "$SRC/gebucht/index.html" "$F"
clean_page "$F" "../"
echo "OK gebucht/index.html"

# ── 404 (Fehlerseite) ──
# GitHub Pages serviert /404.html für JEDE fehlende URL, egal in welcher
# Tiefe (/alltagstipps/xyz/ → zeigt /404.html). Relative Links würden
# gegen die angefragte URL auflösen und brechen. Darum hier ROOT-ABSOLUTE
# Pfade (führender /), nicht clean_page (das macht relative Pfade).
F="$DST/404.html"
cp "$SRC/404.html" "$F"
sed -i 's|"Landing Page\.html"|"/"|g' "$F"
sed -i 's|"Angebotsseite\.html#|"/angebot/#|g' "$F"
sed -i 's|"Angebotsseite\.html"|"/angebot/"|g' "$F"
sed -i 's|"Alltagstipps\.html"|"/alltagstipps/"|g' "$F"
sed -i 's|"Kontakt\.html"|"/kontakt/"|g' "$F"
sed -i 's|"Impressum\.html#|"/impressum/#|g' "$F"
sed -i 's|"Impressum\.html"|"/impressum/"|g' "$F"
sed -i 's|"Über mich\.html"|"/ueber-mich/"|g' "$F"
# Assets root-absolut (fonts.css etc.)
sed -i 's|href="assets/|href="/assets/|g' "$F"
sed -i "s|url('assets/|url('/assets/|g"   "$F"
sed -i 's|url("assets/|url("/assets/|g'   "$F"
sed -i 's|src="assets/|src="/assets/|g'   "$F"
# Favicon (root-absolut) + noindex injizieren, falls nicht vorhanden
if ! grep -q 'rel="icon"' "$F"; then
  D=$(printf '\035')
  BLOCK='<meta name="robots" content="noindex">\n<link rel="icon" type="image/svg+xml" href="/assets/logo.svg">\n<link rel="icon" type="image/png" href="/assets/logo.png">\n<link rel="apple-touch-icon" href="/assets/logo.png">'
  sed -i "s${D}</title>${D}</title>\n${BLOCK}${D}" "$F"
fi
echo "OK 404.html"

# UPDATE .design SNAPSHOTS
cp "$SRC/Landing Page.html"  "$DST/.design/Landing Page.html"
cp "$SRC/Kontakt.html"       "$DST/.design/Kontakt.html"
cp "$SRC/Angebotsseite.html" "$DST/.design/Angebotsseite.html"
cp "$SRC/Alltagstipps.html"  "$DST/.design/Alltagstipps.html"
cp "$SRC/Impressum.html"     "$DST/.design/Impressum.html"
cp "$SRC/Über mich.html"     "$DST/.design/Über mich.html"
cp "$SRC/404.html"           "$DST/.design/404.html"
mkdir -p "$DST/.design/gebucht"
cp "$SRC/gebucht/index.html" "$DST/.design/gebucht/index.html"
mkdir -p "$DST/.design/alltagstipps"
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung hund-entlaufen; do
  mkdir -p "$DST/.design/alltagstipps/$topic"
  cp "$SRC/alltagstipps/$topic/index.html" "$DST/.design/alltagstipps/$topic/index.html"
done
echo "snapshots updated"

# Resize newly-imported assets (idempotent — only touches files > size cap)
echo "=== Running resize-assets ==="
powershell -ExecutionPolicy Bypass -File "$DST/tools/resize-assets.ps1" -AssetsDir "$DST/assets"

echo "=== Running post-import-fixes ==="
bash "$DST/tools/post-import-fixes.sh"
