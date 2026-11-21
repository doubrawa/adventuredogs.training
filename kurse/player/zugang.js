/* Zugangsseite (kurs/): Code eingeben, danach die Kursübersicht.

   Ist auf dem Gerät ein gültiger Code gemerkt, erscheint gleich die Übersicht.
   ?ziel=<id> führt nach dem Anmelden direkt in diese Lektion (ziel=arbeitsheft
   ins Heft) – so landet, wer einen Lektionslink ohne Zugang öffnet, nach dem
   Code wieder dort. */
(function () {
  'use strict';

  const Kurs = window.Kurs;
  const element = Kurs.element;
  const ziel = new URLSearchParams(location.search).get('ziel');
  const $ = function (id) { return document.getElementById(id); };
  const feld = $('code');

  function zeige(teil) {
    ['laden', 'zugang', 'uebersicht'].forEach(function (name) { $(name).hidden = name !== teil; });
    $('abmelden').hidden = teil !== 'uebersicht' || Kurs.klartext;
    $('klartext-marke').hidden = !Kurs.klartext;
  }

  function meldung(text) {
    const kasten = $('code-fehler');
    kasten.textContent = text || '';
    kasten.hidden = !text;
  }

  /* Fortschritt einer Lektion, wie der Abspieler ihn ablegt */
  function fortschritt(id) {
    const s = Kurs.ablage(id + ':');
    return { schritt: Number(s.lesen('schritt', 0)) || 0, anzahl: Number(s.lesen('anzahl', 0)) || 0, fertig: s.lesen('fertig', false) === true };
  }

  function lektionsKarte(l) {
    const offen = !l.geplant || Kurs.klartext;
    const stand = fortschritt(l.id);
    const karte = element('li', 'lektion-karte');
    if (!offen) karte.classList.add('geplant');
    else if (stand.fertig) karte.classList.add('fertig');
    else if (stand.schritt > 0) karte.classList.add('begonnen');

    const nummer = element('span', 'lektion-nr', l.nummer || '');
    nummer.setAttribute('aria-hidden', 'true');
    karte.appendChild(nummer);

    const titel = element(offen ? 'a' : 'span', 'lektion-titel', Kurs.ohneUmbruch(l.titel));
    if (offen) titel.href = Kurs.lektionsLink(l.id);
    titel.setAttribute('aria-label', (l.nummer ? 'Lektion ' + l.nummer + ': ' : '') + l.titel);
    karte.appendChild(titel);

    const meta = [];
    if (l.dauer) meta.push(l.dauer);
    if (!offen) meta.push('in Arbeit');
    else if (Kurs.klartext && l.geplant) meta.push('Entwurf');
    if (meta.length) karte.appendChild(element('span', 'lektion-meta', meta.join(' · ')));

    if (offen) {
      let status = 'Starten';
      if (stand.fertig) status = 'Abgeschlossen';
      else if (stand.schritt > 0 && stand.anzahl) status = 'Schritt ' + stand.schritt + ' von ' + stand.anzahl;
      const marke = element('span', 'lektion-status');
      if (stand.fertig) marke.appendChild(Kurs.symbol('i-haken'));
      marke.appendChild(document.createTextNode(status));
      karte.appendChild(marke);
      if (stand.schritt > 0 && stand.anzahl && !stand.fertig) {
        const balken = element('span', 'lektion-balken');
        const fuellung = element('span');
        fuellung.style.width = Math.min(100, Math.round(stand.schritt / stand.anzahl * 100)) + '%';
        balken.appendChild(fuellung);
        balken.setAttribute('aria-hidden', 'true');
        karte.appendChild(balken);
      }
    }
    return { karte: karte, fertig: offen && stand.fertig, offen: offen };
  }

  function uebersicht(kurs) {
    const ablage = $('module');
    ablage.textContent = '';
    let offen = 0;
    let fertig = 0;
    kurs.module.forEach(function (modul) {
      const abschnitt = element('section', 'modul');
      const kopf = element('div', 'modul-kopf');
      kopf.appendChild(element('p', 'schritt-marke', modul.nummer === '0' ? 'Zum Einstieg' : 'Modul ' + modul.nummer));
      kopf.appendChild(element('h2', 'modul-titel', modul.titel));
      abschnitt.appendChild(kopf);
      const liste = element('ol', 'lektionen');
      modul.lektionen.forEach(function (l) {
        const ergebnis = lektionsKarte(l);
        if (ergebnis.offen) offen += 1;
        if (ergebnis.fertig) fertig += 1;
        liste.appendChild(ergebnis.karte);
      });
      abschnitt.appendChild(liste);
      ablage.appendChild(abschnitt);
    });
    $('uebersicht-stand').textContent = fertig + ' von ' + offen + ' Lektionen abgeschlossen';
    Kurs.verlinke(document);
    zeige('uebersicht');
  }

  /* replace statt href: Die Zugangsseite bleibt nicht als Zwischenschritt im
     Verlauf, sonst führte „Zurück“ aus der Lektion hierher und gleich wieder vor */
  function weiterZumZiel() {
    if (!ziel) return false;
    location.replace(ziel === 'arbeitsheft' ? Kurs.arbeitsheftLink() : Kurs.lektionsLink(ziel));
    return true;
  }

  /* Codefeld: beim Tippen in Vierergruppen setzen. Die Schreibmarke bleibt
     hinter demselben Zeichen, eine Rücktaste direkt hinter einem Strich
     löscht das Zeichen davor (Entfernen vor einem Strich das danach).
     Während einer Eingabe mit Wortvorschlag (Komposition) wartet das Feld,
     bis sie fertig ist. */
  let bisher = '';
  function zeichenVon(text) { return text.toUpperCase().replace(/[^0-9A-Z]/g, ''); }
  function setzeCode(art) {
    const wert = feld.value;
    let zeichen = zeichenVon(wert);
    let davor = zeichenVon(wert.slice(0, feld.selectionStart === null ? wert.length : feld.selectionStart)).length;
    if (zeichen === bisher && art === 'deleteContentBackward' && davor > 0) {
      zeichen = zeichen.slice(0, davor - 1) + zeichen.slice(davor);
      davor -= 1;
    } else if (zeichen === bisher && art === 'deleteContentForward') {
      zeichen = zeichen.slice(0, davor) + zeichen.slice(davor + 1);
    }
    zeichen = zeichen.slice(0, 16);
    davor = Math.min(davor, zeichen.length);
    bisher = zeichen;
    const neu = Kurs.formatiere(zeichen);
    if (neu !== wert) {
      feld.value = neu;
      const stelle = davor === 0 ? 0 : davor + Math.floor((davor - 1) / 4);
      if (document.activeElement === feld) feld.setSelectionRange(stelle, stelle);
    }
    meldung('');
  }
  feld.addEventListener('input', function (ev) { if (!ev.isComposing) setzeCode(ev.inputType); });
  feld.addEventListener('compositionend', function () { setzeCode(''); });

  $('zugang-form').addEventListener('submit', async function (ev) {
    ev.preventDefault();
    const eingabe = feld.value;
    if (!Kurs.normalisiere(eingabe)) {
      meldung('Der Code hat 16 Zeichen in Vierergruppen. Prüf bitte die Schreibweise.');
      feld.focus();
      return;
    }
    const knopf = $('oeffnen');
    const beschriftung = knopf.querySelector('span');
    knopf.disabled = true;
    beschriftung.textContent = 'Code wird geprüft …';
    meldung('');
    try {
      await Kurs.anmelden(eingabe, $('merken').checked);
      if (weiterZumZiel()) return;
      const kurs = await Kurs.ladeKurs();
      if (!kurs) throw new Error('Kurs nach dem Anmelden nicht geladen');
      uebersicht(kurs);
      $('uebersicht-titel').tabIndex = -1;
      $('uebersicht-titel').focus();
    } catch (e) {
      if (e.grund === 'unbekannt' || e.grund === 'falsch') {
        meldung('Dieser Code passt nicht oder gilt nicht mehr. Prüf bitte die Schreibweise oder schreib Julia.');
      } else if (e.grund === 'speicher') {
        meldung('Der Code stimmt, aber dein Browser lässt diese Seite nichts speichern. Erlaube Websitedaten (Cookies) für adventuredogs.training oder öffne den Kurs in einem anderen Browser.');
      } else {
        console.error(e);
        meldung('Das hat gerade nicht geklappt. Prüf deine Internetverbindung und versuch es noch einmal.');
      }
      feld.focus();
    } finally {
      knopf.disabled = false;
      beschriftung.textContent = 'Kurs öffnen';
    }
  });

  $('abmelden').addEventListener('click', function () {
    if (!window.confirm('Auf diesem Gerät abmelden? Danach brauchst du deinen Zugangscode, um den Kurs wieder zu öffnen. Dein Fortschritt bleibt gespeichert.')) return;
    Kurs.abmelden();
    feld.value = '';
    bisher = '';
    meldung('');
    zeige('zugang');
  });

  async function start() {
    if (!Kurs.verfuegbar()) {
      zeige('zugang');
      meldung('Dieser Browser kann den Kurs nicht öffnen. Bitte nimm einen aktuellen Browser.');
      $('oeffnen').disabled = true;
      return;
    }
    try {
      const kurs = await Kurs.ladeKurs();
      if (kurs) {
        if (weiterZumZiel()) return;
        uebersicht(kurs);
        return;
      }
    } catch (e) {
      console.error(e);
      zeige('zugang');
      meldung('Der Kurs ließ sich gerade nicht laden. Prüf deine Internetverbindung und lade die Seite neu.');
      return;
    }
    zeige('zugang');
    if (Kurs.hinweisAbholen() === 'abgelaufen') meldung('Dein Zugang gilt nicht mehr: Die Zugangszeit ist vorbei, oder der Code wurde gesperrt. Wenn das nicht stimmen kann, schreib Julia.');
  }

  /* Zurück aus einer Lektion: Fortschritt und Anmeldung frisch zeigen */
  Kurs.beiRueckkehr(function () { location.reload(); });

  start();
})();
