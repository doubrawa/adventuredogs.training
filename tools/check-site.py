#!/usr/bin/env python3
"""Prueft die Website vor dem Commit.

Aufruf:  py tools/check-site.py        (oder: python3 tools/check-site.py)

Bis zum 08.09.2026 gab es hier gar nichts. Was die Seiten korrekt machte, hing
allein daran, dass post-import-fixes.sh es nach jedem Design-Import neu
injizierte; als dieses Skript wegfiel, blieb nur noch "daran denken". Dieses
Skript nimmt die Kontrollen, die vorher niemand machte:

  1. Seitenliste  - deckt sich tools/pages.tsv mit dem, was auf der Platte liegt?
  2. SEO          - hat jede Seite title, description, canonical, og:*, viewport?
  3. Verweise     - loesen alle internen href/src auf eine existierende Datei auf?
  4. Sitemaps     - wohlgeformt, und decken sie sich mit pages.tsv?
  5. Bilder       - keine Ausreisser bei Maessen und Gewicht
  6. Seitengewicht- bleibt jede Seite unter dem Budget?

FEHLER blockieren (Exit 1), WARNUNG nicht. tools/hooks/pre-commit ruft das
Skript auf, damit niemand mehr daran denken muss.
"""
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = os.path.join(WURZEL, 'tools', 'pages.tsv')

# Ordner, die nicht zur Website gehoeren.
IGNORIERT = {'.git', 'tools', 'assets', 'willkommensmappe', 'available_images'}

# Seiten, die absichtlich in keiner Sitemap stehen.
AUSNAHMEN = {'404.html', 'gebucht/index.html'}

# Dateien in assets/, auf die bewusst keine Seite zeigt.
#
# logo.svg ist die Vektorvorlage der Bildmarke. Bis zum 08.09.2026 wurde sie
# als Nav-Logo und als Favicon ausgeliefert - 137 KB fuer eine Darstellung bei
# hoechstens 46 px. Seither kommen dafuer logo-144.webp und die PNG-Favicons
# zum Einsatz. Die Vorlage bleibt liegen, weil man aus ihr jede Groesse neu
# rastern kann; ausgeliefert wird sie nicht mehr.
VORLAGEN = {'logo.svg'}

# Was im <head> jeder gelisteten Seite stehen muss.
PFLICHT_TAGS = [
    ('title',       r'<title>[^<]{10,}</title>'),
    ('description', r'<meta\s+name="description"\s+content="[^"]{30,}"'),
    ('canonical',   r'<link\s+rel="canonical"\s+href="https://adventuredogs\.training[^"]*"'),
    ('og:title',    r'property="og:title"'),
    ('og:image',    r'property="og:image"'),
    ('viewport',    r'<meta\s+name="viewport"'),
]
# Nice to have, aber kein Grund zu blockieren.
KUER_TAGS = [('JSON-LD', r'application/ld\+json')]

# Seitenbudget: Summe aus HTML + Schriften + ALLEN referenzierten Bildern.
#
# Das ist bewusst nicht das, was ein Besucher beim ersten Aufruf laedt - die
# meisten Bilder haengen an loading="lazy" und kommen erst beim Scrollen.
# Gemessen am 08.09.2026: die Startseite laedt live 704 KB, waehrend die Summe
# hier bei 1753 KB liegt. Die Zahl taugt also nicht als Ladezeit, wohl aber als
# Sperrklinke gegen Wachstum: die Schwellen liegen knapp ueber dem heutigen
# schwersten Fall (/angebot/ mit rund 2300 KB), damit heute alles durchgeht und
# ein unbedachtes weiteres Grossbild auffaellt.
SEITE_FEHLER_KB = 3000
SEITE_WARNUNG_KB = 2500

# Einzelbild. Die Breite ist hart - dieselbe Grenze, die resize-assets.ps1 zieht.
# Ein Kriterium fuer Bytes je Megapixel steht hier bewusst NICHT: darueber
# entscheidet resize-assets.ps1, und zwar erst nach einem Probelauf, ob sich
# ein Neukodieren ueberhaupt lohnt. Ein zweites Urteil an dieser Stelle wuerde
# genau die Dateien anmahnen, die dort gerade als "kein Gewinn" durchgefallen
# sind. Was bleibt, ist eine absolute Obergrenze gegen echte Ausreisser.
BILD_MAX_BREITE = 2400
BILD_MAX_KB = 700

fehler = []
warnungen = []


def melde_fehler(bereich, text):
    fehler.append((bereich, text))


def melde_warnung(bereich, text):
    warnungen.append((bereich, text))


def lies_pages():
    """tools/pages.tsv -> Liste von dicts."""
    if not os.path.exists(PAGES):
        print('FEHLER: tools/pages.tsv fehlt.')
        sys.exit(1)
    zeilen = []
    with open(PAGES, encoding='utf-8') as f:
        for nr, roh in enumerate(f, 1):
            if roh.strip().startswith('#') or not roh.strip():
                continue
            teile = roh.rstrip('\n').split('\t')
            if len(teile) != 6:
                melde_fehler('Seitenliste',
                             'pages.tsv Zeile %d hat %d statt 6 Tab-Spalten' % (nr, len(teile)))
                continue
            zeilen.append(dict(zip(
                ('url', 'datei', 'changefreq', 'prioritaet', 'lastmod', 'bilder'), teile)))
    return zeilen


def html_dateien():
    """Alle HTML-Dateien der Website, relativ zur Wurzel, mit / als Trenner."""
    gefunden = []
    for ordner, unter, dateien in os.walk(WURZEL):
        unter[:] = [u for u in unter if u not in IGNORIERT and not u.startswith('.')]
        for name in dateien:
            if name.endswith('.html'):
                rel = os.path.relpath(os.path.join(ordner, name), WURZEL)
                gefunden.append(rel.replace(os.sep, '/'))
    return sorted(gefunden)


def webp_masse(kopf):
    """(Breite, Hoehe) aus einem WebP-Kopf. Drei Varianten, drei Ablagen."""
    art = kopf[12:16]
    if art == b'VP8X':                       # erweitert: Leinwandgroesse, je 24 Bit, minus 1
        b = int.from_bytes(kopf[24:27], 'little') + 1
        h = int.from_bytes(kopf[27:30], 'little') + 1
        return b, h
    if art == b'VP8 ':                       # verlustbehaftet: je 14 Bit
        b, h = struct.unpack('<HH', kopf[26:30])
        return b & 0x3FFF, h & 0x3FFF
    if art == b'VP8L':                       # verlustfrei: 14 Bit gepackt ab Bit 0
        n = int.from_bytes(kopf[21:25], 'little')
        return (n & 0x3FFF) + 1, ((n >> 14) & 0x3FFF) + 1
    return None


def bildmasse(pfad):
    """(Breite, Hoehe) fuer JPEG, PNG und WebP, sonst None."""
    try:
        with open(pfad, 'rb') as f:
            kopf = f.read(32)
            if kopf[:8] == b'\x89PNG\r\n\x1a\n':
                return struct.unpack('>II', kopf[16:24])
            if kopf[:4] == b'RIFF' and kopf[8:12] == b'WEBP':
                return webp_masse(kopf)
            if kopf[:2] != b'\xff\xd8':
                return None
            f.seek(2)
            daten = f.read()
        i = 0
        while i < len(daten) - 9:
            if daten[i] != 0xFF:
                i += 1
                continue
            marker = daten[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                          0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                hoehe, breite = struct.unpack('>HH', daten[i + 5:i + 9])
                return breite, hoehe
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack('>H', daten[i + 2:i + 4])[0]
    except Exception:
        return None
    return None


# ---------------------------------------------------------------- 1. Seitenliste
def pruefe_seitenliste(pages):
    gelistet = {p['datei'] for p in pages}
    auf_platte = set(html_dateien())
    for datei in sorted(auf_platte - gelistet - AUSNAHMEN):
        melde_fehler('Seitenliste',
                     '%s liegt auf der Platte, steht aber nicht in pages.tsv '
                     '(sonst fehlt sie in beiden Sitemaps)' % datei)
    for datei in sorted(gelistet - auf_platte):
        melde_fehler('Seitenliste', '%s steht in pages.tsv, existiert aber nicht' % datei)
    for p in pages:
        if p['lastmod'] not in ('git', 'anlage'):
            melde_fehler('Seitenliste',
                         '%s: lastmod ist "%s", erlaubt sind git|anlage' % (p['datei'], p['lastmod']))
        if p['bilder'] not in ('ja', 'nein'):
            melde_fehler('Seitenliste',
                         '%s: bilder ist "%s", erlaubt sind ja|nein' % (p['datei'], p['bilder']))


# ------------------------------------------------------------------------ 2. SEO
def pruefe_seo(pages):
    for p in pages:
        pfad = os.path.join(WURZEL, p['datei'].replace('/', os.sep))
        if not os.path.exists(pfad):
            continue
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        kopf = text[:text.find('</head>')] if '</head>' in text else text
        for name, muster in PFLICHT_TAGS:
            if not re.search(muster, kopf, re.I):
                melde_fehler('SEO', '%s: %s fehlt oder ist zu kurz' % (p['datei'], name))
        for name, muster in KUER_TAGS:
            if not re.search(muster, kopf, re.I):
                melde_warnung('SEO', '%s: %s fehlt' % (p['datei'], name))
        # canonical muss auf die eigene URL zeigen, nicht auf eine andere Seite.
        treffer = re.search(r'<link\s+rel="canonical"\s+href="([^"]+)"', kopf, re.I)
        if treffer:
            soll = 'https://adventuredogs.training' + p['url']
            if treffer.group(1).rstrip('/') + '/' != soll.rstrip('/') + '/':
                melde_fehler('SEO', '%s: canonical zeigt auf %s statt auf %s'
                             % (p['datei'], treffer.group(1), soll))


# -------------------------------------------------------------------- 3. Verweise
def pruefe_verweise():
    anzahl = 0
    for rel in html_dateien():
        pfad = os.path.join(WURZEL, rel.replace('/', os.sep))
        ordner = os.path.dirname(pfad)
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        for treffer in re.finditer(r'(?:href|src)="([^"#][^"]*)"', text):
            ziel = treffer.group(1)
            if ziel.startswith(('http', 'mailto:', 'tel:', 'data:', '//', '#')):
                continue
            sauber = ziel.split('?')[0].split('#')[0]
            if not sauber:
                continue
            basis = WURZEL if sauber.startswith('/') else ordner
            voll = os.path.normpath(os.path.join(basis, sauber.lstrip('/').replace('/', os.sep)))
            if os.path.isdir(voll):
                voll = os.path.join(voll, 'index.html')
            anzahl += 1
            if not os.path.exists(voll):
                melde_fehler('Verweise', '%s verweist auf %s - existiert nicht' % (rel, ziel))
    return anzahl


# -------------------------------------------------------------------- 4. Sitemaps
def pruefe_sitemaps(pages):
    for name in ('sitemap.xml', 'sitemap-images.xml'):
        pfad = os.path.join(WURZEL, name)
        if not os.path.exists(pfad):
            melde_fehler('Sitemap', '%s fehlt' % name)
            continue
        try:
            baum = ET.parse(pfad)
        except ET.ParseError as e:
            melde_fehler('Sitemap', '%s ist kein wohlgeformtes XML: %s' % (name, e))
            continue
        locs = [e.text for e in baum.getroot().iter()
                if e.tag.endswith('}loc') and e.text and '/assets/' not in e.text]
        if name == 'sitemap.xml':
            soll = {'https://adventuredogs.training' + p['url'] for p in pages}
            for fehlt in sorted(soll - set(locs)):
                melde_fehler('Sitemap', '%s fehlt in sitemap.xml - generate-sitemap.sh laufen lassen' % fehlt)
            for zuviel in sorted(set(locs) - soll):
                melde_fehler('Sitemap', '%s steht in sitemap.xml, aber nicht in pages.tsv' % zuviel)
        else:
            soll = {'https://adventuredogs.training' + p['url']
                    for p in pages if p['bilder'] == 'ja'}
            for zuviel in sorted(set(locs) - soll):
                melde_fehler('Sitemap', '%s steht in sitemap-images.xml, aber nicht in pages.tsv' % zuviel)
        # Bild-URLs muessen auf existierende Dateien zeigen.
        for e in baum.getroot().iter():
            if e.tag.endswith('}loc') and e.text and '/assets/' in e.text:
                datei = e.text.split('/assets/', 1)[1]
                if not os.path.exists(os.path.join(WURZEL, 'assets', datei.replace('/', os.sep))):
                    melde_fehler('Sitemap', '%s listet assets/%s - existiert nicht' % (name, datei))


# ---------------------------------------------------------------------- 5. Bilder
def bildverwendung():
    """Trennt die Assets danach, wer sie laedt.

    Seit der WebP-Umstellung am 08.09.2026 gibt es zwei Sorten: die WebP-
    Dateien, die im Browser gerendert werden, und die JPEG-Originale, die nur
    noch als og:image im Quelltext stehen. Letztere holt kein Besucher - sie
    werden einmal von einem Social-Crawler geholt, wenn jemand den Link teilt.
    Die Gewichtsschwelle auf beide anzuwenden hiesse, ein 721-KB-Hero
    anzumahnen, das niemand herunterlaedt.
    """
    gerendert, irgendwo = set(), set()
    for rel in html_dateien():
        text = open(os.path.join(WURZEL, rel.replace('/', os.sep)),
                    encoding='utf-8', errors='ignore').read()
        for muster in (r'<img[^>]*?src="[^"]*assets/([^"]+)"',
                       r'url\(\s*[\'"]?[^)\'"]*assets/([^)\'"]+)',
                       r'<link[^>]*?rel="preload"[^>]*?href="[^"]*assets/([^"]+)"'):
            gerendert.update(m.group(1) for m in re.finditer(muster, text, re.I))
        # Fuer die Verwaisungsfrage zaehlt jede Erwaehnung, egal in welcher
        # Rolle: og:image, JSON-LD, <link rel="icon">, ein <a href> auf das
        # PDF. Eng gefasste Muster wuerden hier zuverlaessig danebengreifen.
        irgendwo.update(m.group(1) for m in re.finditer(r'assets/([A-Za-z0-9._%-]+)', text))
    return gerendert, irgendwo


def pruefe_bilder():
    ordner = os.path.join(WURZEL, 'assets')
    gerendert, irgendwo = bildverwendung()
    for name in sorted(os.listdir(ordner)):
        pfad = os.path.join(ordner, name)
        if not os.path.isfile(pfad) or not name.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
            continue
        masse = bildmasse(pfad)
        if not masse:
            continue
        breite, _hoehe = masse
        groesse = os.path.getsize(pfad)

        # Die Breite gilt fuer alle: ein 4000-px-Bild ist auch als og:image
        # falsch, und es zeigt, dass jemand ein Original ungeprueft abgelegt hat.
        if breite > BILD_MAX_BREITE:
            melde_fehler('Bilder', '%s ist %d px breit (max %d) - resize-assets.ps1 laufen lassen'
                         % (name, breite, BILD_MAX_BREITE))

        # Das Gewicht nur da, wo es ein Besucher bezahlt.
        if name in gerendert and groesse / 1024 > BILD_MAX_KB:
            melde_warnung('Bilder', '%s wiegt %d KB (Schwelle %d) - resize-assets.ps1 pruefen'
                          % (name, groesse / 1024, BILD_MAX_KB))

    verwaist = sorted(n for n in os.listdir(ordner)
                      if os.path.isfile(os.path.join(ordner, n))
                      and n not in irgendwo and n not in VORLAGEN)
    for name in verwaist:
        melde_warnung('Bilder', '%s wird von keiner Seite referenziert' % name)


# --------------------------------------------------------------- 6. Seitengewicht
def pruefe_gewicht(pages):
    schriften = 0
    ordner = os.path.join(WURZEL, 'assets', 'fonts')
    if os.path.isdir(ordner):
        schriften = sum(os.path.getsize(os.path.join(ordner, n)) for n in os.listdir(ordner))
    zeilen = []
    for p in pages:
        pfad = os.path.join(WURZEL, p['datei'].replace('/', os.sep))
        if not os.path.exists(pfad):
            continue
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        assets = set(re.findall(r'assets/([A-Za-z0-9._%-]+\.(?:jpg|jpeg|png|webp|svg|gif))', text, re.I))
        gewicht = os.path.getsize(pfad) + schriften
        for a in assets:
            ap = os.path.join(WURZEL, 'assets', a)
            if os.path.exists(ap):
                gewicht += os.path.getsize(ap)
        kb = gewicht / 1024
        zeilen.append((kb, p['url'], len(assets)))
        if kb > SEITE_FEHLER_KB:
            melde_fehler('Gewicht', '%s waere %d KB schwer (Grenze %d KB)' % (p['url'], kb, SEITE_FEHLER_KB))
        elif kb > SEITE_WARNUNG_KB:
            melde_warnung('Gewicht', '%s waere %d KB schwer (Warnschwelle %d KB)'
                          % (p['url'], kb, SEITE_WARNUNG_KB))
    return sorted(zeilen, reverse=True)


def main():
    pages = lies_pages()
    pruefe_seitenliste(pages)
    pruefe_seo(pages)
    verweise = pruefe_verweise()
    pruefe_sitemaps(pages)
    pruefe_bilder()
    gewichte = pruefe_gewicht(pages)

    print('  %d Seiten, %d interne Verweise, %d Bilder in assets/'
          % (len(pages), verweise,
             len([n for n in os.listdir(os.path.join(WURZEL, 'assets'))
                  if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))])))
    if gewichte:
        kb, url, n = gewichte[0]
        print('  schwerste Seite: %s mit %d KB an Bildern insgesamt (%d Stueck);'
              % (url, kb, n))
        print('    beim ersten Aufruf laedt der Browser davon nur einen Bruchteil (lazy).')

    for bereich, text in warnungen:
        print('  WARNUNG  [%s] %s' % (bereich, text))
    for bereich, text in fehler:
        print('  FEHLER   [%s] %s' % (bereich, text))

    if fehler:
        print('\n  %d Fehler - Commit besser erst nach der Korrektur.' % len(fehler))
        return 1
    print('  alles in Ordnung%s' % (' (%d Warnungen)' % len(warnungen) if warnungen else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
