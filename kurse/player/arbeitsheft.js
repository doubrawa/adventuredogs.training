/* Arbeitsheft: sammelt die Druckblätter aller Lektionen samt den eigenen
   Einträgen zu einem Heft, das man in einem Rutsch druckt oder als PDF
   speichert.

   Aufruf: kurse/<kurs>/arbeitsheft/ (verschlüsselt) oder auf localhost
   kurse/<kurs>/arbeitsheft/?klartext (Quellen aus /onlinekurs/<kurs>/, siehe kurs.js).

   Je Lektion lädt die Seite den Ausschnitt über kurs.js, nimmt daraus das
   .druckblatt und füllt es aus der Ablage dieses Geräts – mit derselben
   Funktion wie der Abspieler (Kurs.fuelleDruckblatt). Jedes Blatt steckt in
   einem <article class="ah-blatt" data-lektion="…">: auf dem Bildschirm das
   Papier, im Heft der Träger der eigenen Stile einer Lektion. Die hängen im
   Abspieler an body[data-lektion="…"] und werden hier auf das Blatt
   umgehängt, damit sich die Lektionen im Heft nicht gegenseitig verstellen.

   Die Gestaltung der Blätter (.druckblatt, .db-…) gilt in lernseite.css auch
   auf dem Bildschirm; im Abspieler ist das Blatt dort nur unsichtbar. So
   sieht die Vorschau aus wie das Papier.

   Die Seite schickt nichts weg: Einträge und Hundename bleiben im
   localStorage dieses Geräts. */
(function () {
  'use strict';

  const Kurs = window.Kurs;
  const element = Kurs.element;
  const geraet = Kurs.ablage('');
  const heft = Kurs.ablage('arbeitsheft:');
  const HUND_SCHLUESSEL = Kurs.PRAEFIX + 'arbeitsheft:hund';
  const $ = function (id) { return document.getElementById(id); };
  const blaetter = [];

  /* ── Stilblätter als Text umschreiben ──────────────────────────────────── */
  /* Bewusst über den Text und nicht über das CSSOM: Chrome gibt Regeln mit
     var() in einer Kurzschreibweise, die eine Langform überschreibt, als
     „border-right-color: ;“ aus – beim Wiedereinlesen fiele die Angabe weg.
     Hier bleiben die Deklarationen wörtlich, umgeschrieben werden nur die
     Selektoren und @media-Köpfe. */
  const RUECKSTRICH = '\\';
  function ohneKommentare(css) { return css.replace(/\/\*[\s\S]*?\*\//g, ''); }
  function hinterZeichenkette(css, i) {     /* css[i] ist " oder ' */
    const zeichen = css[i];
    for (i += 1; i < css.length; i++) {
      if (css[i] === RUECKSTRICH) i += 1;
      else if (css[i] === zeichen) return i;
    }
    return css.length;
  }
  function naechstes(css, i) {              /* nächstes { ; oder } außerhalb von Zeichenketten */
    for (; i < css.length; i++) {
      const z = css[i];
      if (z === '"' || z === "'") i = hinterZeichenkette(css, i);
      else if (z === '{' || z === ';' || z === '}') return i;
    }
    return css.length;
  }
  function passendeKlammer(css, i) {        /* css[i] ist { */
    let tiefe = 0;
    for (; i < css.length; i++) {
      const z = css[i];
      if (z === '"' || z === "'") i = hinterZeichenkette(css, i);
      else if (z === '{') tiefe += 1;
      else if (z === '}' && --tiefe === 0) return i;
    }
    return css.length;
  }
  /* Regelliste in Blöcke { kopf, innen } zerlegen; @import und andere
     Anweisungen ohne Block fallen weg */
  function bloecke(css) {
    const liste = [];
    let i = 0;
    while (i < css.length) {
      const j = naechstes(css, i);
      if (j >= css.length) break;
      if (css[j] !== '{') { i = j + 1; continue; }
      const zu = passendeKlammer(css, j);
      liste.push({ kopf: css.slice(i, j).trim(), innen: css.slice(j + 1, zu) });
      i = zu + 1;
    }
    return liste;
  }
  /* Selektorliste an den Kommas der obersten Ebene teilen – nicht in :is(…),
     [title="a, b"] oder Zeichenketten */
  function teileSelektor(liste) {
    const teile = [];
    let tiefe = 0;
    let anfang = 0;
    for (let i = 0; i < liste.length; i++) {
      const z = liste[i];
      if (z === '"' || z === "'") i = hinterZeichenkette(liste, i);
      else if (z === '(' || z === '[') tiefe += 1;
      else if (z === ')' || z === ']') tiefe -= 1;
      else if (z === ',' && tiefe === 0) { teile.push(liste.slice(anfang, i).trim()); anfang = i + 1; }
    }
    teile.push(liste.slice(anfang).trim());
    return teile.filter(Boolean);
  }

  /* ── Eigene Stile einer Lektion aufs Blatt umhängen ────────────────────── */
  /* Im Abspieler beginnt jede Regel mit body[data-lektion="<id>"]
     (pruefen.mjs mahnt alles andere an). Hier trägt das .ah-blatt diese
     Kennung. Was nicht so beginnt oder am Zustand von body hängt
     (body[…][data-art=…], body[…].ohne-text), bleibt draußen, ebenso
     @keyframes und Ähnliches. @media print gilt im Heft auch auf dem
     Bildschirm, wie die Gestaltung der Blätter. */
  function lektionsStile(text, kennung) {
    const vorher = 'body[data-lektion="' + kennung + '"]';
    const nachher = '.ah-blatt[data-lektion="' + kennung + '"]';
    function umhaengen(css) {
      return bloecke(css).map(function (b) {
        if (b.kopf.charAt(0) === '@') {
          if (!/^@(media|supports)\b/i.test(b.kopf)) return '';
          const innen = umhaengen(b.innen);
          return innen ? b.kopf.replace(/\bprint\b/gi, 'all') + ' {\n' + innen + '}\n' : '';
        }
        const neu = teileSelektor(b.kopf)
          .filter(function (s) { return s.indexOf(vorher) === 0 && /^\s+(?:>\s*)?[^\s+~>]/.test(s.slice(vorher.length)); })
          .map(function (s) { return nachher + s.slice(vorher.length); });
        return neu.length ? neu.join(', ') + ' {' + b.innen + '}\n' : '';
      }).join('');
    }
    return umhaengen(ohneKommentare(text));
  }
  /* Vor arbeitsheft.css einfügen, damit die Feinheiten dort bei gleicher Spezifität gewinnen */
  function vorArbeitsheftCss(id, text) {
    if (!text.trim()) return;
    const stil = element('style');
    stil.id = id;
    stil.textContent = text;
    document.head.insertBefore(stil, document.querySelector('link[href$="arbeitsheft.css"]'));
  }

  /* ── Laden ─────────────────────────────────────────────────────────────── */
  /* Ein Druckblatt samt Angaben zur Lektion; null ohne Ausschnitt oder Blatt.
     Geladen werden nur die Dateien, auf die das Blatt selbst verweist – nicht
     Ton und Bilder der ganzen Lektion. */
  async function ladeBlatt(kurs, lektion) {
    const artikel = await Kurs.ladeArtikel(kurs, lektion);
    const blatt = artikel && artikel.querySelector('.druckblatt');
    if (!blatt) return null;
    Kurs.setzeVerweise(blatt, await Kurs.dateien(kurs, lektion, Kurs.verweise(blatt)));

    const d = artikel.dataset;
    const kopf = blatt.querySelector('.db-kopf h1');
    return {
      lektion: lektion,
      kennung: d.lektion || lektion.id,
      nummer: d.nummer || lektion.nummer || '',
      titel: d.titel || lektion.titel,
      blattTitel: (kopf && kopf.textContent.trim()) || d.titel || lektion.titel,
      blatt: blatt,
      stile: Array.from(artikel.querySelectorAll('style'), function (s) { return s.textContent; }).join('\n')
    };
  }

  /* ── Werte eintragen ───────────────────────────────────────────────────── */
  function fuelle(eintrag) {
    eintrag.stand = Kurs.fuelleDruckblatt(eintrag.blatt, function (name) {
      return geraet.lesen(Kurs.feldSchluessel(eintrag.kennung, name), '');
    });
  }

  /* ── Inhaltsverzeichnis ────────────────────────────────────────────────── */
  function inhaltsKarte(eintrag) {
    const karte = element('li', 'lektion-karte');
    const nummer = element('span', 'lektion-nr', eintrag.nummer);
    nummer.setAttribute('aria-hidden', 'true');
    karte.appendChild(nummer);

    const lektionsName = (eintrag.nummer ? 'Lektion ' + eintrag.nummer + ': ' : '') + eintrag.titel;
    const titel = element('a', 'lektion-titel', Kurs.ohneUmbruch(eintrag.blattTitel));
    titel.href = '#' + eintrag.artikel.id;
    titel.setAttribute('aria-label', eintrag.blattTitel + ' aus ' + lektionsName + ', in der Vorschau zeigen');
    karte.appendChild(titel);

    const meta = [Kurs.ohneUmbruch(eintrag.titel)];
    if (Kurs.klartext && eintrag.lektion.geplant) meta.push('Entwurf');
    karte.appendChild(element('span', 'lektion-meta', meta.join(' · ')));

    const fuss = element('div', 'ah-karte-fuss');
    eintrag.status = element('span', 'lektion-status');
    fuss.appendChild(eintrag.status);
    const link = element('a', 'ah-zur-lektion', 'zur Lektion');
    link.href = Kurs.lektionsLink(eintrag.lektion.id);
    link.setAttribute('aria-label', 'Zur ' + lektionsName);
    link.appendChild(Kurs.symbol('i-rechts'));
    fuss.appendChild(link);
    karte.appendChild(fuss);
    return karte;
  }

  function zeigeStand(eintrag) {
    const s = eintrag.stand;
    const alles = s.gesamt > 0 && s.ausgefuellt === s.gesamt;
    eintrag.karte.classList.toggle('fertig', alles);
    eintrag.karte.classList.toggle('begonnen', s.ausgefuellt > 0 && !alles);
    let text = 'ohne Felder';
    if (alles) text = 'alles ausgefüllt';
    else if (s.ausgefuellt) text = s.ausgefuellt + ' von ' + s.gesamt + ' Feldern ausgefüllt';
    else if (s.gesamt) text = 'noch leer';
    eintrag.status.textContent = '';
    if (alles) eintrag.status.appendChild(Kurs.symbol('i-haken'));
    eintrag.status.appendChild(document.createTextNode(text));
  }

  function anzahlText(sichtbar, aus) {
    const blaetterText = function (n) { return n + (n === 1 ? ' Blatt' : ' Blätter'); };
    if (!sichtbar) return aus ? blaetterText(aus) + ' ohne Einträge ausgeblendet' : '';
    return blaetterText(sichtbar) + (aus ? ' · ' + aus + ' ohne Einträge ausgeblendet' : '');
  }

  /* Auswahl „nur Blätter mit Einträgen“: Blatt und Karte gemeinsam aus */
  function filtere() {
    const nurMitEintraegen = $('nur-eintraege').checked;
    let sichtbar = 0;
    blaetter.forEach(function (e) {
      const zeigen = !nurMitEintraegen || e.stand.ausgefuellt > 0;
      e.artikel.hidden = !zeigen;
      e.karte.hidden = !zeigen;
      if (zeigen) sichtbar += 1;
    });
    $('anzahl').textContent = anzahlText(sichtbar, blaetter.length - sichtbar);
    $('nichts-eingetragen').hidden = sichtbar > 0 || !blaetter.length;
  }

  function aktualisiere() {
    blaetter.forEach(function (e) { fuelle(e); zeigeStand(e); });
    filtere();
  }

  /* ── Deckblatt: Name des Hundes ────────────────────────────────────────── */
  function zeigeHund() {
    const name = $('hund').value.trim();
    const ziel = $('deck-hund');
    ziel.textContent = name;
    ziel.classList.toggle('leer', !name);
  }
  function liesHund() {
    const feld = $('hund');
    if (document.activeElement === feld) return;
    feld.value = String(heft.lesen('hund', '') || '');
    zeigeHund();
  }

  /* ── Heft aufbauen ─────────────────────────────────────────────────────── */
  function zeigeHeft(kurs, eintraege, fehlgeschlagen) {
    if (kurs.titel) $('deck-kurs').textContent = kurs.titel;
    const fuss = document.querySelector('body > .fuss');
    const verzeichnis = $('verzeichnis');
    const stile = [];
    eintraege.forEach(function (e) {
      /* Im Abspieler ist das Blatt nur für den Druck da; hier ist es Inhalt.
         Die Überschriften ordnen sich unter die der Seite. */
      e.blatt.removeAttribute('aria-hidden');
      ['h1', 'h2', 'h3'].forEach(function (tag, i) {
        e.blatt.querySelectorAll(tag).forEach(function (h) { h.setAttribute('aria-level', String(i + 3)); });
      });
      e.artikel = element('article', 'ah-blatt');
      e.artikel.id = 'blatt-' + e.lektion.id;
      e.artikel.dataset.lektion = e.kennung;
      e.artikel.appendChild(e.blatt);
      document.body.insertBefore(e.artikel, fuss);
      e.karte = inhaltsKarte(e);
      verzeichnis.appendChild(e.karte);
      if (e.stile.trim()) stile.push(lektionsStile(e.stile, e.kennung));
      blaetter.push(e);
    });
    vorArbeitsheftCss('ah-lektionsstile', stile.join('\n'));

    $('keine-blaetter').hidden = blaetter.length > 0;
    $('drucken').disabled = !blaetter.length;
    if (fehlgeschlagen) {
      $('nicht-geladen').textContent = (fehlgeschlagen === 1 ? 'Ein Blatt ließ' : fehlgeschlagen + ' Blätter ließen')
        + ' sich gerade nicht laden. Prüf deine Internetverbindung und lade die Seite neu.';
      $('nicht-geladen').hidden = false;
    }
    aktualisiere();

    document.body.dataset.art = 'heft';
    $('laden').hidden = true;
    $('heft').hidden = false;
    $('deckblatt').hidden = false;
  }

  function fehler(titel, text) {
    document.body.dataset.art = 'fehler';
    $('laden').hidden = true;
    const kasten = $('fehler');
    Kurs.fuelleFehler(kasten, titel, text);
    kasten.hidden = false;
  }

  /* ── Bedienung ─────────────────────────────────────────────────────────── */
  function verdrahte() {
    Kurs.verlinke(document);
    $('klartext-marke').hidden = !Kurs.klartext;

    const feld = $('hund');
    liesHund();
    feld.addEventListener('input', function () { heft.schreiben('hund', feld.value); zeigeHund(); });

    document.querySelectorAll('input[name="blaetter"]').forEach(function (r) { r.addEventListener('change', filtere); });
    $('drucken').addEventListener('click', function () { aktualisiere(); window.print(); });

    /* Ist eine Lektion in einem anderen Tab offen, kommen neue Einträge
       gleich hier an – das Heft ist beim Drucken immer auf dem Stand.
       Lektionsfelder und kursweite Felder gleichermaßen (Schema in kurs.js). */
    window.addEventListener('storage', function (ev) {
      if (ev.key !== null && ev.key.indexOf(Kurs.PRAEFIX) !== 0) return;
      if (ev.key === null || ev.key === HUND_SCHLUESSEL) liesHund();
      if (ev.key === null || ev.key.indexOf(':feld:') !== -1) aktualisiere();
    });

    /* Zurück aus einer Lektion (Zwischenspeicher des Browsers): frisch lesen,
       nach dem Abmelden gar nicht erst zeigen */
    Kurs.beiRueckkehr(function () {
      if (!Kurs.klartext && !Kurs.hatCode()) { location.replace(Kurs.uebersichtsLink('arbeitsheft')); return; }
      liesHund();
      aktualisiere();
    });
  }

  async function los() {
    verdrahte();
    if (!Kurs.verfuegbar()) {
      return fehler('Dieser Browser kann den Kurs nicht öffnen', 'Bitte öffne den Kurs in einem aktuellen Browser.');
    }

    let kurs;
    try {
      kurs = await Kurs.ladeKurs();
    } catch (e) {
      console.error(e);
      return fehler('Das Arbeitsheft ließ sich nicht laden', 'Prüf deine Internetverbindung und versuch es gleich noch einmal.');
    }
    if (!kurs) { location.replace(Kurs.uebersichtsLink('arbeitsheft')); return; }

    /* Verschlüsselt nur freigegebene Lektionen; im Klartext alle, deren
       Ausschnitt schon existiert (die übrigen liefern 404 und fallen weg) */
    const kandidaten = Kurs.alleLektionen(kurs).filter(function (l) {
      return Kurs.klartext ? !!l.ordner : !l.geplant && !!l.inhalt;
    });
    const balken = $('laden-fortschritt');
    balken.max = kandidaten.length || 1;
    let fertig = 0;
    let fehlgeschlagen = 0;
    const geladen = await Promise.all(kandidaten.map(async function (l) {
      try {
        return await ladeBlatt(kurs, l);
      } catch (e) {
        console.error('Blatt aus Lektion ' + l.id + ' nicht geladen:', e);
        fehlgeschlagen += 1;
        return null;
      } finally {
        fertig += 1;
        balken.value = fertig;
      }
    }));
    zeigeHeft(kurs, geladen.filter(Boolean), fehlgeschlagen);
  }

  los();
})();
