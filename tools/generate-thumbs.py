#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt die kleinen Vorschaubilder der Alltagstipps als WebP.

Die Kartenraster auf der Hub-Seite und die "Weiterlesen"-Karten der
Detailseiten rendern bei rund 400 px Breite. Den vollen Hero dafuer zu laden
waere Verschwendung, also entsteht hier je Thema ein 800 px breites Bild
(= 2x fuer scharfe Displays).

Loest generate-thumbs.ps1 ab. Grund: System.Drawing, das die PowerShell-
Fassung benutzte, kann kein WebP schreiben - und seit dem 08.09.2026 sind
alle im Browser gerenderten Bilder WebP. Pillow kann es.

Idempotent ueber die Zeitstempel: neu gebaut wird nur, was aelter ist als
seine Quelle.

Aufruf:  py tools/generate-thumbs.py [--force]
"""
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

try:
    from PIL import Image
except ImportError:
    print('FEHLER: Pillow fehlt.  py -m pip install pillow')
    sys.exit(1)

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(WURZEL, 'assets')
MAX_BREITE = 800
QUALITAET = 80
FORCE = '--force' in sys.argv

# Thema -> Quellbild, aus dem das Vorschaubild abgeleitet wird.
# Die Quellen sind die JPEG-Originale, nicht deren WebP-Ableitungen: aus dem
# groesseren Original skaliert es sauberer als aus einem bereits komprimierten
# Zwischenschritt.
THUMBS = [
    ('welpenzeit',         'offer-welpenkurs.jpg'),
    ('silvester',          'hero-silvester.jpg'),
    ('urlaub',             'hero-urlaub.jpg'),
    ('winter',             'hero-winter.jpg'),
    ('alleinbleiben',      'hero-alleinbleiben.jpg'),
    ('tierphysiotherapie', 'hero-tierphysiotherapie.jpg'),
    ('ernaehrung',         'hero-ernaehrung.jpg'),
    ('hund-entlaufen',     'hero-hund-entlaufen.jpg'),
]

gebaut = uebersprungen = fehlend = 0

for slug, quelle in THUMBS:
    src = os.path.join(ASSETS, quelle)
    dst = os.path.join(ASSETS, 'thumb-%s.webp' % slug)

    if not os.path.exists(src):
        print('  fehlt (Quelle): %s' % quelle)
        fehlend += 1
        continue

    if not FORCE and os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
        uebersprungen += 1
        continue

    im = Image.open(src)
    breite, hoehe = im.size
    if breite > MAX_BREITE:
        neu_h = round(hoehe * MAX_BREITE / breite)
        im = im.resize((MAX_BREITE, neu_h), Image.LANCZOS)
    else:
        neu_h = hoehe

    # Erst in eine Tempdatei, dann umbenennen: ein Abbruch mittendrin laesst
    # sonst ein halbes Bild im Ordner liegen.
    tmp = dst + '.tmp'
    im.convert('RGB').save(tmp, 'WEBP', quality=QUALITAET, method=6)
    os.replace(tmp, dst)

    gebaut += 1
    print('  OK   thumb-%s.webp: %d KB (%dx%d) aus %s (%d KB)'
          % (slug, os.path.getsize(dst) / 1024, im.width, neu_h,
             quelle, os.path.getsize(src) / 1024))

if gebaut == 0 and fehlend == 0:
    print('  alle %d Vorschaubilder aktuell' % uebersprungen)
else:
    print('  %d gebaut, %d aktuell, %d ohne Quelle' % (gebaut, uebersprungen, fehlend))

sys.exit(1 if fehlend else 0)
