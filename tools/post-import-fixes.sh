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

# ─── Nav-Media-Query: toter Bereich unterhalb des Hamburgers ───
# Das Design bringt seit v53 eine Media-Query, die den fünften Nav-Eintrag
# ("Office Dogs") bei mittleren Breiten enger setzt — deklariert ab 821px.
# .nav-links wird aber schon ab 960px per `display:none !important` vom
# Hamburger abgelöst, der Bereich 821–960px läuft also ins Leere.
# Untergrenze auf 961px anheben, damit die Query genau dort greift, wo die
# Desktop-Nav auch wirklich sichtbar ist.
for f in "$DST/index.html" "$DST"/*/index.html "$DST"/alltagstipps/*/index.html "$DST/404.html"; do
    [ -f "$f" ] || continue
    if grep -q 'min-width: 821px' "$f"; then
        sed -i 's|min-width: 821px|min-width: 961px|g' "$f"
        NAVQ=$((${NAVQ:-0} + 1))
    fi
done
[ "${NAVQ:-0}" -gt 0 ] && echo "  Nav-Media-Query 821px → 961px: $NAVQ Seiten"

# ─── Nav-Geometrie an officedogs.training angleichen ───
# Beide Sites verlinken sich gegenseitig in der Nav. Beim Domainwechsel bleibt
# die Leiste stehen, ihre Maße sprangen aber sichtbar (gemessen bei 1280px):
#
#                       officedogs   adventuredogs
#   Balkenhöhe             80px          70px
#   Rand links           51,2px        63,2px
#   Logo                   46px       42/40px
#   Button-Höhe          41,0px        35,6px
#
# officedogs ist die Referenz (Wunsch von Juergen, 05.08.2026). Dessen
# `clamp(22px,4vw,52px)` ersetzt die 5%: officedogs deckelt den Rand bei 52px,
# 5% wachsen unbegrenzt weiter (bei 1920px 96px → 44px Sprung). Dass die Nav
# dadurch weiter außen sitzt als der Inhalt (7%), ist gewollt und auf
# officedogs genauso — die Nav ist ein Rahmenelement am Fensterrand, nicht am
# Textblock ausgerichtet. Sie überlagert ohnehin einen bildschirmhohen Hero.
#
# Nebeneffekt, der hier gleich mit erledigt wird: die Nav war schon site-intern
# uneinheitlich — Startseite Logo 42px / Abstand 32px, Unterseiten 40px / 28px.
# Beides geht auf officedogs' 46px / 30px.
#
# Die Link-Schriftgröße 14px → 13,5px ist nötig, damit der Button exakt und
# nicht nur ungefähr gleich dick wird (Höhe = Polster + Textzeile); 13,5px ist
# im Design ohnehin schon der Wert der 961–1120px-Query.
#
# Alle Ersetzungen sind mit perl auf die jeweilige Regel begrenzt. Ein
# pauschales sed wäre falsch: `padding: 9px 20px` sitzt auf angebot/ auch an
# den Termine-Tabs, `gap: 32px` und `font-size: 14px` kommen vielfach vor.
# Sobald das in claude.ai/design korrigiert ist, läuft der Block leer.
NAVG=0
for f in "$DST/index.html" "$DST"/*/index.html "$DST"/alltagstipps/*/index.html "$DST/404.html"; do
    [ -f "$f" ] || continue
    grep -q 'height: 70px\|padding: 0 5%\|top: 70px' "$f" || continue
    perl -0777 -i -pe '
        s/(\bnav \{[^}]*?)height: 70px/${1}height: 80px/s;
        s/(\bnav \{[^}]*?)padding: 0 5%/${1}padding: 0 clamp(22px, 4vw, 52px)/s;
        s/\.nav-logo img \{ width: 4[02]px; height: 4[02]px; \}/.nav-logo img { width: 46px; height: 46px; }/;
        s/(\.nav-links \{[^}]*?)gap: (?:28|32)px/${1}gap: 30px/s;
        s/(\.nav-links a \{[^}]*?)font-size: 14px/${1}font-size: 13.5px/s;
        s/(\.nav-cta \{[^}]*?)padding: 9px 20px/${1}padding: 12px 22px/s;
        s/(\.nav-mobile \{[^}]*?)top: 70px/${1}top: 80px/s;
        s/(\.nav-mobile \{[^}]*?padding: \d+px )7%/${1}clamp(22px, 4vw, 52px)/s;
    ' "$f"
    # Toter Rest: die 720px-Query setzte nav-padding auf denselben Wert wie die
    # Basisregel. Mit dem clamp wäre sie sogar schädlich (5% = 18,75px auf 375px
    # statt der 22px, die officedogs dort hat).
    sed -i '/^    nav { padding: 0 5%; }$/d' "$f"
    NAVG=$((NAVG + 1))
done
[ "$NAVG" -gt 0 ] && echo "  Nav-Geometrie auf officedogs-Maße: $NAVG Seiten"

# Sprungmarken in den Artikeln: 90px Freiraum waren auf die 70px-Nav gerechnet
# (20px Luft). Mit 80px Nav bleiben sonst nur 10px.
SMT=0
for f in "$DST"/alltagstipps/*/index.html; do
    [ -f "$f" ] || continue
    if grep -q 'scroll-margin-top: 90px' "$f"; then
        sed -i 's|scroll-margin-top: 90px|scroll-margin-top: 100px|g' "$f"
        SMT=$((SMT + 1))
    fi
done
[ "$SMT" -gt 0 ] && echo "  Artikel-Sprungmarken 90px → 100px: $SMT Seiten"

# ─── Hero-Badge: WhatsApp-Kanal statt Kurs-Event ───
# Der Badge im Hero ist ein einzelner Slot, den das Design mit dem jeweils
# nächsten Kurstermin füllt (großes Datum, Ringtext, Ablaufdatum). Er bewirbt
# stattdessen dauerhaft den WhatsApp-Kanal (Entscheidung Juergen, 06.08.2026).
#
# Statt eines Worts steht das WhatsApp-Logo im Kreis. Die große Zeile ist
# gemessen auf 64px begrenzt (Telefon, Playfair 900) — das Wort "WhatsApp"
# braucht dort 131px und passt nie hinein, am Desktop ebenso wenig (Budget 98).
# Das Logo verbraucht keines der knappen Zeichen, dafür kann der Ring sagen,
# was drin ist. Der Ring fasst 515 Einheiten Umfang; der neue Text füllt 58 %
# davon (der alte 44 %). Über rund 65 % schließt sich die Lücke im Kreis.
#
# Farbe bleibt der Seiten-Akzent (Teal), nicht WhatsApp-Grün: das Logo trägt
# die Wiedererkennung, ein zweites Grün würde die Palette brechen.
#
# aria-label ist nötig, weil der Ringtext aria-hidden ist und im Kreis kein
# Text mehr steht — ohne das Label hieße der Link für Screenreader nur "Folgen".
#
# ACHTUNG: Der Block überschreibt JEDEN Badge aus dem Design. Bringt ein
# künftiger Export ein neues Kurs-Event mit, geht es hier verloren. Deshalb die
# Warnung unten, wenn der vorgefundene Link nicht der bekannte alte ist. Dann
# ist zu entscheiden: Event oder Kanal — es gibt nur diesen einen Platz.
BADGE_URL="https://whatsapp.com/channel/0029Vb6dtpM0LKZ9QcRCBj0V"
BF="$DST/index.html"
if grep -q 'class="hero-badge"' "$BF" && ! grep -q "$BADGE_URL" "$BF"; then
    ALT=$(grep -o 'class="hero-badge"[^>]*' "$BF" | sed 's|.*href="||;s|".*||')
    case "$ALT" in
        *123hundeschule.de/kurse/139-jagen-nein-danke*) ;;
        *) echo "  WARNUNG: Hero-Badge zeigte auf $ALT — nicht auf das bekannte"
           echo "           Jagen-Nein-Danke-Event. Falls das ein neues Kurs-Event aus dem"
           echo "           Design war, wurde es soeben durch den WhatsApp-Kanal ersetzt." ;;
    esac

    # Markup. Das Logo ist die Standard-Wortmarke (Hörer in der Sprechblase);
    # sie auf den eigenen WhatsApp-Auftritt zu verlinken ist der vorgesehene
    # Gebrauch. fill:currentColor, damit es das Weiß des Badges erbt.
    NEWBADGE=$(cat <<'HTML'
  <a class="hero-badge" data-expires="2026-12-31" href="https://whatsapp.com/channel/0029Vb6dtpM0LKZ9QcRCBj0V" target="_blank" rel="noopener" aria-label="Adventure Dogs Training auf WhatsApp folgen">
    <svg class="badge-spin" viewBox="0 0 200 200" aria-hidden="true">
      <defs><path id="badgeTextPath" d="M100,100 m-82,0 a82,82 0 1,1 164,0 a82,82 0 1,1 -164,0"/></defs>
      <text><textPath href="#badgeTextPath" startOffset="0">WhatsApp-Kanal&nbsp;&nbsp;·&nbsp;&nbsp;Tipps &amp; Termine&nbsp;&nbsp;&nbsp;&nbsp;</textPath></text>
    </svg>
    <svg class="badge-logo" viewBox="0 0 24 24" aria-hidden="true"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>
    <span class="badge-cta">Folgen <svg viewBox="0 0 24 24" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span>
  </a>
HTML
)
    # Kein \n im Muster und im Ersatz: frisch aus dem Design importiert hat die
    # Datei LF, frisch aus git ausgecheckt dagegen CRLF (autocrlf). Ein Muster
    # auf </a>\n trifft dann nur im ersten Fall und laeuft im zweiten still ins
    # Leere. So bleibt das Zeilenende einfach unangetastet.
    NEWBADGE="$NEWBADGE" perl -0777 -i -pe 's!^  <a class="hero-badge".*?</a>!$ENV{NEWBADGE}!sm' "$BF"

    # CSS: .badge-date wird durch .badge-logo ersetzt statt ergänzt, sonst
    # bliebe eine tote Regel stehen. Zwei Vorkommen, Basis zuerst, danach die
    # 720px-Query — beide ohne /g, damit die zweite Ersetzung die Mobilregel
    # trifft. cta-long entfällt: "Folgen" ist mit 53px auch auf dem Telefon
    # kurz genug (Budget 64), es gibt also nichts mehr auszublenden.
    #
    # Delimiter ist !, nicht {}: perl zählt geschweifte Klammern als Delimiter
    # paarweise durch und beendet das Suchmuster sonst am } in [^}].
    CSS_BASE='.hero-badge .badge-logo { width: 34px; height: 34px; fill: currentColor; flex: none; }' \
    CSS_MOBI='.hero-badge .badge-logo { width: 24px; height: 24px; }' \
    perl -0777 -i -pe '
        s!\.hero-badge \.badge-date \{[^}]*\}!$ENV{CSS_BASE}!s;
        s!\.hero-badge \.badge-date \{[^}]*\}!$ENV{CSS_MOBI}!s;
    ' "$BF"
    sed -i '/^    \.hero-badge \.cta-long { display: none; }$/d' "$BF"

    grep -q "$BADGE_URL" "$BF" || { echo "FEHLER: Hero-Badge nicht ersetzt — Markup im Export geaendert?"; exit 1; }
    grep -q 'badge-date' "$BF" && { echo "FEHLER: .badge-date ist uebrig geblieben (tote Regel oder Markup)."; exit 1; }
    echo "  Hero-Badge: WhatsApp-Kanal (sichtbar bis 31.12.2026)"
fi

# ─── Impressum: TMG → DDG ───
# Das Telemediengesetz wurde im Mai 2024 vom Digitale-Dienste-Gesetz (DDG)
# abgelöst. Das Impressum aus dem Design zitiert noch die alten Normen:
# § 5 TMG (Impressumspflicht) und § 7 Abs. 1 / §§ 8 bis 10 TMG
# (Verantwortlichkeit für eigene/fremde Inhalte). Die Paragrafennummern sind
# im DDG identisch, es ändert sich nur das Kürzel — deshalb reicht ein
# pauschales TMG→DDG auf dieser einen Datei.
# Sobald es in claude.ai/design korrigiert ist, läuft der Block leer.
IMP="$DST/impressum/index.html"
if grep -q 'TMG' "$IMP"; then
    sed -i 's|TMG|DDG|g' "$IMP"
    echo "  Impressum: TMG → DDG ($(grep -c 'DDG' "$IMP") Stellen)"
fi

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
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung hund-entlaufen; do
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
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung hund-entlaufen; do
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

    # og:title soll dem echten <title> der Seite folgen (Single Source:
    # das Design-Tool). Abweichende og:title verwirren Google + Social-
    # Previews. Der title-Parameter ist nur noch Fallback, falls die
    # Seite keinen <title> hat. Das Article-Schema liest og:title und
    # bleibt damit automatisch konsistent.
    local page_title=$(grep -oE '<title>[^<]+</title>' "$f" | head -1 | sed 's/<title>//;s/<\/title>//')
    [ -n "$page_title" ] && title="$page_title"

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
  "Silvester mit Hund: Vorbereitung, Rituale und Notfallstrategien gegen Stress durch Böller. Tipps aus der Hundeschule Adventure Dogs in Krumbach." \
  "hero-silvester.jpg"

inject_seo "$DST/alltagstipps/urlaub/index.html" "alltagstipps/urlaub/" \
  "Mit Hund in den Urlaub – Reisetipps | Adventure Dogs" \
  "Mit Hund verreisen: Was du für Auto, Bahn, Flugzeug oder Ferienwohnung planen musst — Tipps aus der Hundeschule Adventure Dogs Krumbach." \
  "hero-urlaub.jpg"

inject_seo "$DST/alltagstipps/winter/index.html" "alltagstipps/winter/" \
  "Winter mit Hund – Pflege und Spaziergänge | Adventure Dogs" \
  "So kommt dein Hund gut durch den Winter: Pfotenpflege, Streusalz, kalte Tage und die richtigen Spaziergänge. Aus Krumbach, Adventure Dogs." \
  "hero-winter.jpg"

inject_seo "$DST/alltagstipps/alleinbleiben/index.html" "alltagstipps/alleinbleiben/" \
  "Alleinbleiben lernen – Schritt für Schritt | Adventure Dogs" \
  "So lernt dein Hund, dass Alleinsein okay ist — fairer und nachhaltiger Trainingsweg. Julia Doubrawa, Adventure Dogs Krumbach." \
  "hero-alleinbleiben.jpg"

inject_seo "$DST/alltagstipps/tierphysiotherapie/index.html" "alltagstipps/tierphysiotherapie/" \
  "Tierphysiotherapie für Hunde – wann sinnvoll? | Adventure Dogs" \
  "Wann eine Tierphysiotherapie für deinen Hund sinnvoll ist und woran du erkennst, dass er Hilfe braucht. Empfehlungen aus Krumbach (Schwaben)." \
  "hero-tierphysiotherapie.jpg"

inject_seo "$DST/alltagstipps/ernaehrung/index.html" "alltagstipps/ernaehrung/" \
  "Hundeernährung Grundlagen – Trocken, Nass, BARF | Adventure Dogs" \
  "Hundeernährung verstehen: Trockenfutter, Nassfutter, BARF — Überblick und Auswahl-Kriterien. Hundeschule Adventure Dogs Krumbach." \
  "hero-ernaehrung.jpg"

inject_seo "$DST/alltagstipps/hund-entlaufen/index.html" "alltagstipps/hund-entlaufen/" \
  "Hund entlaufen – was tun? | Adventure Dogs" \
  "Hund entlaufen? Die wichtigsten Sofortmaßnahmen Schritt für Schritt – plus Notfall-Anlaufstellen für Krumbach, den Landkreis Günzburg und das Unterallgäu." \
  "hero-hund-entlaufen.jpg"

# Gebucht (booking-confirmation page): inject SEO + noindex so Google
# doesn't index this post-conversion landing in search results.
if [ -f "$DST/gebucht/index.html" ]; then
    inject_seo "$DST/gebucht/index.html" "gebucht/" \
      "Buchung bestätigt – Adventure Dogs | Julia Doubrawa" \
      "Buchungsbestätigung der Hundeschule Adventure Dogs in Krumbach." \
      "hero-gebucht.jpg"
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

# ─── Alltagstipps: thumbnail-Variants + card SVG → IMG swap ───
# 1) Generate small thumb-<slug>.jpg from each hero (800px wide, q=80).
#    Cards reference these to avoid loading 7 full heroes on the hub
#    (was ~2.9 MB, now ~0.5 MB).
# 2) Replace the design tool's decorative card SVGs with <img> tags
#    pointing at the thumbs. PowerShell handles multi-line regex;
#    idempotent per-card and per-CSS-rule.
echo "  generating Alltagstipps card thumbnails"
powershell -ExecutionPolicy Bypass -File "$DST/tools/generate-thumbs.ps1" -AssetsDir "$DST/assets"

# ─── Hub-Karte für hund-entlaufen (falls im Design-Hub noch nicht drin) ───
# Der Artikel wurde per Pipeline ergänzt; die Hub-Übersicht kennt ihn u.U.
# noch nicht. Wir hängen die 8. Karte nach der Ernährungs-Karte ein.
# Idempotent: nur wenn href="hund-entlaufen/" auf dem Hub fehlt. Sobald
# Julia die Karte in claude.ai/design selbst pflegt, greift der Check
# und es entsteht kein Duplikat.
HUB="$DST/alltagstipps/index.html"
if [ -f "$HUB" ] && ! grep -q 'href="hund-entlaufen/"' "$HUB"; then
    CARD=$(cat "$DST/tools/hub-card-hund-entlaufen.html")
    # Nach dem schließenden </a> der Ernährungs-Karte einsetzen. Anker ist
    # der eindeutige Ernährungs-Teaser; wir splicen direkt vor dem Grid-Ende.
    line=$(grep -n 'card-teaser">Trocken, nass, BARF' "$HUB" | head -1 | cut -d: -f1)
    if [ -n "$line" ]; then
        # Ende der Ernährungs-Karte = erstes </a> ab der Teaser-Zeile
        endrel=$(tail -n +"$line" "$HUB" | grep -n '</a>' | head -1 | cut -d: -f1)
        endline=$((line + endrel - 1))
        tmp=$(mktemp)
        head -n "$endline" "$HUB"          > "$tmp"
        cat "$DST/tools/hub-card-hund-entlaufen.html" >> "$tmp"
        tail -n +$((endline + 1)) "$HUB"   >> "$tmp"
        mv "$tmp" "$HUB"
        echo "  injected hub card: hund-entlaufen"
    fi
fi
# "7 Themen" → "8 Themen" (nur wenn hund-entlaufen-Karte jetzt vorhanden)
if grep -q 'href="hund-entlaufen/"' "$HUB" && grep -q '7 Themen' "$HUB"; then
    sed -i 's/7 Themen/8 Themen/g' "$HUB"
    echo "  bumped hub count: 8 Themen"
fi

echo "  swapping Alltagstipps card SVGs → IMGs"
powershell -ExecutionPolicy Bypass -File "$DST/tools/swap-card-svgs.ps1" -RepoRoot "$DST"

# ─── BreadcrumbList JSON-LD auf Alltagstipps-Hub + Detail-Seiten ───
# Strukturierte Breadcrumb-Hierarchie für Google. Hub bekommt
# 2-Level (Home → Alltagstipps), Detail-Seiten 3-Level (Home →
# Alltagstipps → Topic). Topic-Display-Name aus dem <title>-Tag
# extrahiert (alles vor " – Alltagstipps").
inject_breadcrumb_schema() {
    local f="$1"
    local url="$2"
    local topic_name="$3"   # Anzeige-Name; leer für Hub-Page
    if grep -q '"@type": "BreadcrumbList"' "$f"; then return; fi

    local items
    if [ -z "$topic_name" ]; then
        # Hub: Home → Alltagstipps (kein href am letzten Element)
        items='[
    {"@type": "ListItem", "position": 1, "name": "Adventure Dogs", "item": "'"$SITE_BASE"'/"},
    {"@type": "ListItem", "position": 2, "name": "Alltagstipps"}
  ]'
    else
        items='[
    {"@type": "ListItem", "position": 1, "name": "Adventure Dogs", "item": "'"$SITE_BASE"'/"},
    {"@type": "ListItem", "position": 2, "name": "Alltagstipps", "item": "'"$SITE_BASE"'/alltagstipps/"},
    {"@type": "ListItem", "position": 3, "name": "'"$topic_name"'"}
  ]'
    fi

    local schema='<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": '"$items"'
}
</script>'

    # Nach der Description-Meta-Zeile einfügen (gleicher Trick wie
    # andere Schema-Injections).
    local desc_line=$(grep -n '<meta name="description"' "$f" | head -1 | cut -d: -f1)
    if [ -n "$desc_line" ]; then
        local tmp=$(mktemp)
        head -n "$desc_line" "$f"          > "$tmp"
        echo "$schema"                     >> "$tmp"
        tail -n +$((desc_line + 1)) "$f"   >> "$tmp"
        mv "$tmp" "$f"
        echo "  injected Breadcrumb JSON-LD: $(echo "$url" | sed 's|'"$SITE_BASE"'||')"
    fi
}
# Display-Namen pro Topic. Halten wir hier explizit, damit der
# Schema-Output kontrolliert bleibt (kein Parsing aus dem H1, das
# Markup-Reste haben kann).
inject_breadcrumb_schema "$DST/alltagstipps/index.html" "$SITE_BASE/alltagstipps/" ""
inject_breadcrumb_schema "$DST/alltagstipps/welpenzeit/index.html" \
    "$SITE_BASE/alltagstipps/welpenzeit/" "Welpenzeit gestalten"
inject_breadcrumb_schema "$DST/alltagstipps/silvester/index.html" \
    "$SITE_BASE/alltagstipps/silvester/" "Silvester ohne Stress"
inject_breadcrumb_schema "$DST/alltagstipps/urlaub/index.html" \
    "$SITE_BASE/alltagstipps/urlaub/" "Mit Hund in den Urlaub"
inject_breadcrumb_schema "$DST/alltagstipps/winter/index.html" \
    "$SITE_BASE/alltagstipps/winter/" "Winter mit Hund"
inject_breadcrumb_schema "$DST/alltagstipps/alleinbleiben/index.html" \
    "$SITE_BASE/alltagstipps/alleinbleiben/" "Alleinbleiben lernen"
inject_breadcrumb_schema "$DST/alltagstipps/tierphysiotherapie/index.html" \
    "$SITE_BASE/alltagstipps/tierphysiotherapie/" "Tierphysiotherapie verstehen"
inject_breadcrumb_schema "$DST/alltagstipps/ernaehrung/index.html" \
    "$SITE_BASE/alltagstipps/ernaehrung/" "Hundeernährung Grundlagen"
inject_breadcrumb_schema "$DST/alltagstipps/hund-entlaufen/index.html" \
    "$SITE_BASE/alltagstipps/hund-entlaufen/" "Hund entlaufen"

# ─── "Veröffentlicht · <Monat> <Jahr>" dynamisch aus Content-Datum ───
# Das Design-Tool schreibt ein statisches Datum in die Artikel-Hero-Meta.
# Das veraltet sichtbar. Wir ersetzen den Monat/Jahr-Teil durch das echte
# Erstelldatum aus git (konsistent mit datePublished im Article-Schema).
#
# Das Label-Wort kam bis v52 als "Aktualisiert", seit v53 als
# "Veröffentlicht". Beide werden erkannt, damit ein Wortwechsel im Design
# das Datum nicht wieder statisch werden lässt — genau das war nach dem
# v53-Import kurzzeitig der Fall.
german_month() {
    case "$1" in
        01) echo "Januar";; 02) echo "Februar";; 03) echo "März";;
        04) echo "April";;  05) echo "Mai";;     06) echo "Juni";;
        07) echo "Juli";;   08) echo "August";;  09) echo "September";;
        10) echo "Oktober";; 11) echo "November";; 12) echo "Dezember";;
    esac
}
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung hund-entlaufen; do
    F="$DST/alltagstipps/$topic/index.html"
    [ -f "$F" ] || continue
    # Erstelldatum = erstes git-Add des Artikels (gleiche Quelle wie
    # datePublished im Article-Schema). NICHT das Änderungs-/Snapshot-Datum:
    # an einem fertigen Artikel ändert sich inhaltlich nichts, und ein
    # Modified-Datum wurde von globalen Änderungen (z.B. Logo-Swap im
    # gemeinsamen Header) fälschlich bei jedem Import hochgezogen.
    d=$(git -C "$DST" log --format=%cd --date=short --diff-filter=A -- "alltagstipps/$topic/index.html" 2>/dev/null | tail -1)
    # Neuer Artikel noch nicht committet → git-Datum leer → heute nehmen.
    [ -z "$d" ] && d=$(date -u +%Y-%m-%d)
    label="$(german_month "${d:5:2}") ${d:0:4}"
    # Ersetzt alles nach dem Label-Wort + " · " bis zum nächsten Tag durch
    # das Content-Datum. Deckt alle Formen ab: echtes "Mai 2026", Klammer-
    # Platzhalter "[Monat Jahr]" (bei neuen Artikeln) und leer.
    # Der Umlaut in "Veröffentlicht" wird über [^ ]* umschifft — Git-Bash-sed
    # matcht ö in Punkt/Klassen unzuverlässig, "Ver" und "ffentlicht" sind
    # dagegen sauberes ASCII.
    # Der Idempotenz-Check muss BEIDE Formen erkennen: auf manchen Seiten
    # folgt direkt "</span>", auf anderen endet die Zeile nach dem Datum und
    # das Tag steht eine Zeile tiefer. Ohne das "(<|$)" schrieb der Block dort
    # bei jedem Lauf denselben Wert neu — harmlos, aber eben nicht idempotent.
    W='(Aktualisiert|Ver[^ ]*ffentlicht)'
    if grep -qE "$W · " "$F" && ! grep -qE "$W · $label(<|$)" "$F"; then
        sed -i -E "s#($W · )[^<]*#\1$label#" "$F"
        echo "  Datums-Label gesetzt: $topic → $label"
    fi
done

# ─── FAQ-Accordion: aria-expanded für Screenreader ───
# Die Buttons togglen nur eine CSS-Klasse — Screenreader erfahren nicht,
# ob ein Panel offen ist. Wir setzen initial aria-expanded="false" und
# patchen das Toggle-JS, damit es das Attribut mitführt.
F="$DST/kontakt/index.html"
if [ -f "$F" ] && ! grep -q 'aria-expanded' "$F"; then
    sed -i 's|<button class="faq-question">|<button class="faq-question" aria-expanded="false">|g' "$F"
    sed -i "s|document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));|document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));\n      document.querySelectorAll('.faq-question').forEach(b => b.setAttribute('aria-expanded', 'false'));|" "$F"
    sed -i "s|if (!isOpen) item.classList.add('open');|if (!isOpen) { item.classList.add('open'); btn.setAttribute('aria-expanded', 'true'); }|" "$F"
    echo "  added aria-expanded to FAQ accordion: kontakt"
fi

# ─── rel-Attribute für externe Empfehlungs-/Affiliate-Links ───
# Platinum-Affiliate-Link (auf /alltagstipps/ernaehrung/) braucht
# rel="sponsored nofollow" — sonst kann Google die Domain als
# kommerziell-betrieben einstufen und das Trust-Signal schwächt.
# Lena-Hillenbrand-WhatsApp-Link (auf /alltagstipps/tierphysiotherapie/)
# kriegt rel="nofollow" — Empfehlung ohne Bezahlung, soll trotzdem
# keinen PageRank an Lena's wa.me-Link verlieren.
F="$DST/alltagstipps/ernaehrung/index.html"
if [ -f "$F" ] && grep -q 'platinum.com.*rel="noopener"' "$F"; then
    sed -i 's|\(href="https://www.platinum.com[^"]*" target="_blank" \)rel="noopener"|\1rel="sponsored nofollow noopener"|g' "$F"
    echo "  added rel=sponsored nofollow to Platinum links: ernaehrung"
fi
F="$DST/alltagstipps/tierphysiotherapie/index.html"
if [ -f "$F" ] && grep -q 'wa.me/[0-9]*" target="_blank" rel="noopener"' "$F"; then
    sed -i 's|\(href="https://wa.me/[0-9]*" target="_blank" \)rel="noopener"|\1rel="nofollow noopener"|g' "$F"
    echo "  added rel=nofollow to Lena WhatsApp link: tierphysiotherapie"
fi

# ─── Article JSON-LD on Alltagstipps detail pages ───
# Schema.org Article-Markup pro Detail-Seite gibt Google strukturierte
# Daten für Rich-Results (Sitelinks, "Top Stories"-Snippets). Pflicht-
# Felder: headline, image, datePublished, author, publisher.
# Werte werden aus den vorhandenen Meta-Tags der jeweiligen Seite
# extrahiert (DRY — Änderung am Title oder OG-Image kommt automatisch
# mit). Idempotent über "@type": "Article"-Sentinel.
inject_article_schema() {
    local f="$1"
    local url="$2"
    if grep -q '"@type": "Article"' "$f"; then return; fi

    # Aus existing meta-Tags ziehen (sed extrahiert content="...")
    local title=$(grep -E '<meta property="og:title"' "$f" | head -1 | sed 's|.*content="\([^"]*\)".*|\1|')
    local desc=$(grep -E '<meta name="description"' "$f" | head -1 | sed 's|.*content="\([^"]*\)".*|\1|')
    local img=$(grep -E '<meta property="og:image"' "$f" | head -1 | sed 's|.*content="\([^"]*\)".*|\1|')

    # datePublished aus dem ersten git-Commit des Files ziehen
    # (--diff-filter=A → erstes Add der Datei, tail -1 = ältester).
    # KEIN --follow: die Artikel teilen viel Boilerplate, wodurch git
    # fälschlich "Umbenennungen" zwischen ihnen erkennt und die Erst-
    # veröffentlichung eines neuen Artikels auf einen älteren zurück-
    # datiert. Ohne --follow gilt das echte erste Add DIESES Pfads.
    # Fallback wenn die Datei noch nicht in git ist: heutiges Datum.
    local rel_path="${f#$DST/}"
    local published=$(git -C "$DST" log --format=%cd --date=short --diff-filter=A -- "$rel_path" 2>/dev/null | tail -1)
    [ -z "$published" ] && published=$(date -u +%Y-%m-%d)
    # dateModified = datePublished (Erstelldatum). An einem fertigen Artikel
    # wird inhaltlich nichts mehr geändert. Frühere Quelle (git-Datum des
    # .design-Snapshots) wurde von globalen Änderungen wie dem Logo-Swap im
    # gemeinsamen Header fälschlich hochgezogen → Datums-Rauschen bei jedem
    # Import. Erstelldatum ist stabil und ehrlich.
    local modified="$published"

    local schema="<script type=\"application/ld+json\">
{
  \"@context\": \"https://schema.org\",
  \"@type\": \"Article\",
  \"headline\": \"${title}\",
  \"description\": \"${desc}\",
  \"image\": \"${img}\",
  \"mainEntityOfPage\": \"${url}\",
  \"author\": {
    \"@type\": \"Person\",
    \"name\": \"Julia Doubrawa\",
    \"url\": \"${SITE_BASE}/ueber-mich/\"
  },
  \"publisher\": {
    \"@type\": \"Organization\",
    \"name\": \"Adventure Dogs\",
    \"logo\": {
      \"@type\": \"ImageObject\",
      \"url\": \"${SITE_BASE}/assets/logo.png\"
    }
  },
  \"datePublished\": \"${published}\",
  \"dateModified\": \"${modified}\"
}
</script>"

    # Einfügen direkt nach der Description-Meta-Zeile (gleicher Trick
    # wie bei LocalBusiness/FAQPage Schemata).
    local desc_line=$(grep -n '<meta name="description"' "$f" | head -1 | cut -d: -f1)
    if [ -n "$desc_line" ]; then
        local tmp=$(mktemp)
        head -n "$desc_line" "$f"          > "$tmp"
        echo "$schema"                     >> "$tmp"
        tail -n +$((desc_line + 1)) "$f"   >> "$tmp"
        mv "$tmp" "$f"
        echo "  injected Article JSON-LD: alltagstipps/$(basename $(dirname "$f"))/"
    fi
}
for topic in welpenzeit silvester urlaub winter alleinbleiben tierphysiotherapie ernaehrung hund-entlaufen; do
    F="$DST/alltagstipps/$topic/index.html"
    [ -f "$F" ] && inject_article_schema "$F" "$SITE_BASE/alltagstipps/$topic/"
done

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

# ─── Sitemap regenerieren (lastmod aus git) ───
bash "$DST/tools/generate-sitemap.sh"

# ─── Image-Sitemap regenerieren ───
# Scant alle HTML-Seiten, sammelt assets/-Image-Refs, schreibt
# sitemap-images.xml. Läuft am Ende, nachdem alle Schemas + Image-
# Swaps drin sind.
powershell -ExecutionPolicy Bypass -File "$DST/tools/generate-image-sitemap.ps1" -RepoRoot "$DST"

echo "post-import fixes done."
