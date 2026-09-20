#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Stutzt die JPEGs, die nur noch als og:image gebraucht werden.

Seit der WebP-Umstellung am 08.09.2026 gibt es in assets/ zwei Sorten JPEG:

  * solche, die eine Seite wirklich rendert (<img src>, CSS-Hintergrund,
    Preload) - die bleiben unangetastet,
  * solche, auf die nur noch og:image, twitter:image oder das image-Feld im
    JSON-LD zeigen. Die holt kein Besucher; sie werden einmal von einem
    Social-Crawler geholt, wenn jemand den Link teilt.

Die zweite Sorte lag bis zum 20.09.2026 in voller Hero-Groesse herum, bis
2400x1602 und 721 KB, zusammen 5,3 MB - Aufloesung, die niemand je sieht.
Facebook, LinkedIn und X zeigen die grosse Vorschaukarte mit 1200 px Breite;
mehr ist verschenkt, weniger als 600 px laesst die Karte auf die kleine
Fassung zurueckfallen.

Deshalb: 1200 px Breite, Seitenverhaeltnis unveraendert. Kein Beschnitt auf
1200x630 - der Ausschnitt jedes Heroes ist am Motiv gewaehlt, und die Karten
schneiden ohnehin selbst zu. Ein Bild, das schon 1200 px oder schmaler ist,
wird nicht hochgerechnet.

Reihenfolge in der Bildpipeline - dieses Skript kommt zuletzt:

    1. resize-assets.ps1   JPEG vom Fotografen auf max. 2400 px (Hero)
    2. nach WebP wandeln   das ist die Datei, die der Browser laedt
    3. resize-og-images.py dieses Skript, stutzt das JPEG auf 1200 px

Nach Schritt 3 ist das WebP die groesste Fassung im Repo. Das volle JPEG
bleibt in der git-Historie erreichbar (git show <commit>:assets/<datei>),
falls man es je wieder braucht.

Idempotent: was bereits passt, wird nicht angefasst. Die Rollenerkennung
liest die Seiten selbst - ein JPEG, das irgendwo gerendert wird, kann das
Skript also gar nicht erwischen, auch nicht nach einer Umbenennung.

Aufruf:  py tools/resize-og-images.py [--dry-run]
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

try:
    from PIL import Image
except ImportError:
    print('FEHLER: Pillow fehlt.  py -m pip install pillow')
    sys.exit(1)

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(WURZEL, 'assets')

MAX_BREITE = 1200
# Dieselbe Qualitaet, die resize-assets.ps1 fuer JPEG setzt.
QUALITAET = 82

TROCKEN = '--dry-run' in sys.argv

# Dieselben Ordner, die check-site.py ausnimmt.
IGNORIERT = {'.git', 'tools', 'assets', 'willkommensmappe', 'available_images'}

# Was zaehlt als "der Browser rendert es". Wortgleich mit check-site.py -
# weichen die beiden Listen auseinander, stutzt dieses Skript ein Bild, das
# check-site.py danach als zu schwer anmahnt, oder umgekehrt.
GERENDERT_MUSTER = (
    r'<img[^>]*?src="[^"]*assets/([^"]+)"',
    r'url\(\s*[\'"]?[^)\'"]*assets/([^)\'"]+)',
    r'<link[^>]*?rel="preload"[^>]*?href="[^"]*assets/([^"]+)"',
)


def html_dateien():
    gefunden = []
    for ordner, unter, dateien in os.walk(WURZEL):
        unter[:] = [u for u in unter if u not in IGNORIERT and not u.startswith('.')]
        for name in dateien:
            if name.endswith('.html'):
                gefunden.append(os.path.join(ordner, name))
    return sorted(gefunden)


def rollen():
    """(gerendert, erwaehnt) - je eine Menge von Dateinamen aus assets/."""
    gerendert, erwaehnt = set(), set()
    for pfad in html_dateien():
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        for muster in GERENDERT_MUSTER:
            gerendert.update(m.group(1) for m in re.finditer(muster, text, re.I))
        erwaehnt.update(m.group(1) for m in re.finditer(r'assets/([A-Za-z0-9._%-]+)', text))
    return gerendert, erwaehnt


def main():
    gerendert, erwaehnt = rollen()

    gestutzt = uebersprungen = 0
    vorher = nachher = 0

    for name in sorted(os.listdir(ASSETS)):
        if not name.lower().endswith(('.jpg', '.jpeg')):
            continue
        pfad = os.path.join(ASSETS, name)
        if not os.path.isfile(pfad):
            continue

        if name in gerendert:
            print('  laedt ein Besucher, bleibt: %s' % name)
            uebersprungen += 1
            continue
        if name not in erwaehnt:
            # Verwaist. check-site.py meldet das ohnehin als Warnung; hier
            # nur nicht anfassen, damit das Skript keine Datei kleinrechnet,
            # ueber deren Verbleib noch gar nicht entschieden ist.
            print('  referenziert niemand, bleibt: %s' % name)
            uebersprungen += 1
            continue

        alt = os.path.getsize(pfad)
        with Image.open(pfad) as im:
            breite, hoehe = im.size
            if breite <= MAX_BREITE:
                print('  schon %d px breit, bleibt: %s' % (breite, name))
                uebersprungen += 1
                continue
            neu_h = round(hoehe * MAX_BREITE / breite)
            klein = im.convert('RGB').resize((MAX_BREITE, neu_h), Image.LANCZOS)

        vorher += alt
        if TROCKEN:
            print('  wuerde stutzen: %s  %dx%d -> %dx%d'
                  % (name, breite, hoehe, MAX_BREITE, neu_h))
            gestutzt += 1
            continue

        # Erst in eine Tempdatei, dann umbenennen - ein Abbruch mittendrin
        # laesst sonst ein halbes Bild liegen. Ohne EXIF und Farbprofil,
        # genau wie resize-assets.ps1.
        tmp = pfad + '.tmp'
        klein.save(tmp, 'JPEG', quality=QUALITAET, optimize=True, progressive=True)
        os.replace(tmp, pfad)
        neu = os.path.getsize(pfad)
        nachher += neu
        gestutzt += 1
        print('  OK   %-30s %4dx%-4d -> %4dx%-4d   %5.0f -> %5.0f KB'
              % (name, breite, hoehe, MAX_BREITE, neu_h, alt / 1024, neu / 1024))

    print()
    if TROCKEN:
        print('  Probelauf: %d zu stutzen, %d unberuehrt' % (gestutzt, uebersprungen))
    else:
        print('  %d gestutzt, %d unberuehrt; %.2f -> %.2f MB (%.2f MB gespart)'
              % (gestutzt, uebersprungen, vorher / 1048576, nachher / 1048576,
                 (vorher - nachher) / 1048576))
    return 0


if __name__ == '__main__':
    sys.exit(main())
