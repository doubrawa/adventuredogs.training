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

# Abweichende Qualitaet je Thema, mit Grund.
#
# silvester: ein Feuerwerk, also tausende feine helle Striche auf Schwarz.
# Bei q80 spart WebP gegenueber dem JPEG nur 5 % - zu wenig, um den Tausch zu
# rechtfertigen, weshalb dieses eine Vorschaubild bis zum 20.09.2026 als JPEG
# liegen blieb. Bei q72 sind es 20 %, und im 100-%-Ausschnitt halten die
# Striche, ohne Ringing auf dem Schwarz. Dasselbe Motiv, dieselbe Zahl: der
# Hero daneben steht aus genau diesem Grund seit dem 09.09.2026 auf q72.
QUALITAET_AUSNAHME = {'silvester': 72}

# Thema -> Quellbild, aus dem das Vorschaubild abgeleitet wird.
#
# Die Quellen sind die WebP-Dateien. Bis zum 20.09.2026 waren es die JPEGs,
# mit der Begruendung, aus dem groesseren Original skaliere es sauberer als
# aus einem bereits komprimierten Zwischenschritt. Seit die JPEGs nur noch
# als og:image gebraucht und dafuer auf 1200 px gestutzt werden, zeigt genau
# diese Begruendung auf die WebP-Datei: sie traegt jetzt die volle Aufloesung,
# das JPEG ist die kleinere Ableitung. Nachgemessen ueber alle acht
# Vorschaubilder: gleiche Masse, 0 bis 9 KB kleiner.
#
# Die Masse haengen an der Quelle: 800 px Breite, Hoehe gerundet. Ein
# Zwischenschritt ueber eine gestutzte Quelle verschiebt sie um bis zu 1 px
# gegen die width/height im HTML - noch ein Grund, hier an der vollen
# Aufloesung zu bleiben.
THUMBS = [
    ('welpenzeit',         'offer-welpenkurs.webp'),
    ('silvester',          'hero-silvester.webp'),
    ('urlaub',             'hero-urlaub.webp'),
    ('winter',             'hero-winter.webp'),
    ('alleinbleiben',      'hero-alleinbleiben.webp'),
    ('tierphysiotherapie', 'hero-tierphysiotherapie.webp'),
    ('ernaehrung',         'hero-ernaehrung.webp'),
    ('hund-entlaufen',     'hero-hund-entlaufen.webp'),
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
    im.convert('RGB').save(tmp, 'WEBP',
                           quality=QUALITAET_AUSNAHME.get(slug, QUALITAET), method=6)
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
