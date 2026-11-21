/* Kurs – gemeinsame Grundlage für Zugangsseite, Lektionsseite und Arbeitsheft
   aller Onlinekurse unter kurse/<kurs>/.

   Welcher Kurs gerade läuft, sagt die Seite selbst am <html>-Element:
     data-kurs="geraeuschangst"   Name des Kurses (Adresse und Speicherbereich)
     data-kursbasis="./"          Weg von dieser Seite zur Startseite des Kurses

   Alle Kursinhalte liegen verschlüsselt unter kurse/<kurs>/daten/: AES-256-GCM mit
   einem Kursschlüssel, jede Datei als  [1 Byte Version][12 Byte IV][Daten+Tag].
   Jeder Zugangscode öffnet in daten/zugang.json ein eigenes Fach, in dem der
   Kursschlüssel liegt: PBKDF2-SHA256 über den Code, Salz je Fach,
   Zusatzdaten „adk-kurs:<Kennung>“. Die ersten vier Zeichen des Codes sind
   die Kennung des Fachs, die übrigen zwölf das Geheimnis (60 Bit).

   Gegenstück ist werkzeuge/bauen.mjs im privaten Kurs-Repo. Normalisierung,
   Formate, Zusatzdaten, die Schlüsselkennung und die Regel für eigene Dateien
   müssen auf beiden Seiten genau gleich bleiben.

   Außerdem steht hier, was alle drei Seiten brauchen: das Schema der Ablage
   im Gerät, das Laden einer Lektion samt ihrer Dateien, das Füllen eines
   Druckblatts, die Links zwischen den Seiten und kleine DOM-Bausteine.

   Klartext-Modus: Auf localhost mit ?klartext lädt die Seite die Quellen
   direkt aus /onlinekurs/<kurs>/, dem Kursordner im lokal geklonten privaten
   Repo – zum Ansehen und Prüfen, bevor etwas verschlüsselt wird. Online gibt es
   diesen Ordner nicht. */
(function () {
  'use strict';

  const seite = document.documentElement.dataset;
  if (!seite.kurs) throw new Error('Kursseite ohne data-kurs am <html>-Element');
  const KURS = seite.kurs;
  const basis = new URL(seite.kursbasis || './', location.href);
  const kodierer = new TextEncoder();

  const lokal = /^(localhost|127\.0\.0\.1|\[::1\])$/.test(location.hostname);
  const klartext = lokal && new URLSearchParams(location.search).has('klartext');
  const QUELLE = new URL('/onlinekurs/' + KURS + '/', location.origin);

  /* ── Codes ─────────────────────────────────────────────────────────────── */
  function normalisiere(eingabe) {
    const s = String(eingabe || '').toUpperCase()
      .replace(/[\s\-_.·]/g, '')
      .replace(/O/g, '0')
      .replace(/[IL]/g, '1');
    return /^[0-9A-HJKMNP-TV-Z]{16}$/.test(s) ? s : null;
  }
  function formatiere(code) { return String(code).replace(/(.{4})(?=.)/g, '$1-'); }

  /* ── Bytes ─────────────────────────────────────────────────────────────── */
  function ausBase64(b64) {
    const roh = atob(b64);
    const bytes = new Uint8Array(roh.length);
    for (let i = 0; i < roh.length; i++) bytes[i] = roh.charCodeAt(i);
    return bytes;
  }
  function zuBase64(bytes) {
    let roh = '';
    for (let i = 0; i < bytes.length; i++) roh += String.fromCharCode(bytes[i]);
    return btoa(roh);
  }
  function alsHex(bytes) {
    return Array.from(bytes, function (b) { return (b < 16 ? '0' : '') + b.toString(16); }).join('');
  }

  /* ── Ablage im Gerät ───────────────────────────────────────────────────── */
  /* Jeder Kurs hat seinen eigenen Bereich; alle Schlüssel beginnen mit
     adk-kurs:<kurs>:
       code, schluessel, hinweis   Zugang (siehe unten, als Text)
       einstellungen:<name>        Tempo, Untertitel, automatisch weiter – für den ganzen Kurs
       <lektion>:<name>            Fortschritt (schritt, anzahl, fertig) und Übungsstände
       <lektion>:feld:<name>       Eingaben einer Lektion
       kurs:feld:<name>            kursweite Eingaben (data-feld="kurs:<name>")
       arbeitsheft:hund            Name auf dem Deckblatt des Hefts
     Die Werte stehen als JSON da. Lässt der Browser nichts speichern
     (privates Fenster, gesperrte Websitedaten), behält die Ablage den Wert
     wenigstens für diese Seite im Arbeitsspeicher. */
  const PRAEFIX = 'adk-kurs:' + KURS + ':';
  const notfall = Object.create(null);
  function ablage(bereich) {
    const voll = function (name) { return PRAEFIX + bereich + name; };
    return {
      lesen: function (name, ersatz) {
        const schluessel = voll(name);
        if (schluessel in notfall) return notfall[schluessel];
        try {
          const roh = localStorage.getItem(schluessel);
          if (roh !== null) return JSON.parse(roh);
        } catch (e) { /* gesperrt oder kein JSON */ }
        return ersatz;
      },
      schreiben: function (name, wert) {
        const schluessel = voll(name);
        try {
          localStorage.setItem(schluessel, JSON.stringify(wert));
          delete notfall[schluessel];
        } catch (e) {
          notfall[schluessel] = wert;
        }
      },
      loeschen: function (name) {
        const schluessel = voll(name);
        delete notfall[schluessel];
        try { localStorage.removeItem(schluessel); } catch (e) { /* gesperrt */ }
      }
    };
  }
  /* Ein Feldname mit „kurs:“ vorn gilt kursweit, alle anderen gehören ihrer
     Lektion. Ergebnis ist ein Name für ablage('') */
  function feldSchluessel(lektion, name) {
    return name.indexOf('kurs:') === 0 ? 'kurs:feld:' + name.slice(5) : lektion + ':feld:' + name;
  }

  /* ── Zugang im Speicher ────────────────────────────────────────────────── */
  const SPEICHER_CODE = PRAEFIX + 'code';
  const SPEICHER_SCHLUESSEL = PRAEFIX + 'schluessel';
  const SPEICHER_HINWEIS = PRAEFIX + 'hinweis';
  function lies(art, name) { try { return window[art].getItem(name); } catch (e) { return null; } }
  function schreib(art, name, wert) {
    try { window[art].setItem(name, wert); return true; } catch (e) { return false; }
  }
  function loesch(art, name) { try { window[art].removeItem(name); } catch (e) { /* gesperrt */ } }

  function gemerkterCode() { return lies('localStorage', SPEICHER_CODE) || lies('sessionStorage', SPEICHER_CODE); }
  function abmelden() {
    loesch('localStorage', SPEICHER_CODE);
    loesch('sessionStorage', SPEICHER_CODE);
    loesch('sessionStorage', SPEICHER_SCHLUESSEL);
  }
  /* Ein Code, der nicht mehr gilt, wird vergessen. Die Zugangsseite sagt
     beim nächsten Aufruf, warum – auch wenn eine Lektion es bemerkt hat. */
  function vergiss() {
    abmelden();
    schreib('sessionStorage', SPEICHER_HINWEIS, 'abgelaufen');
  }
  function hinweisAbholen() {
    const hinweis = lies('sessionStorage', SPEICHER_HINWEIS);
    loesch('sessionStorage', SPEICHER_HINWEIS);
    return hinweis;
  }

  /* ── Verschlüsselung ───────────────────────────────────────────────────── */
  function verfuegbar() { return klartext || !!(window.crypto && window.crypto.subtle && window.TextEncoder); }

  function grundFehler(grund) { const e = new Error(grund); e.grund = grund; return e; }

  async function oeffneFach(code, zugang) {
    const kennung = code.slice(0, 4);
    const fach = zugang && zugang.faecher && zugang.faecher[kennung];
    if (!fach) throw grundFehler('unbekannt');
    const basisSchluessel = await crypto.subtle.importKey('raw', kodierer.encode(code), 'PBKDF2', false, ['deriveKey']);
    const kek = await crypto.subtle.deriveKey(
      { name: 'PBKDF2', salt: ausBase64(fach.salz), iterations: zugang.iterationen, hash: 'SHA-256' },
      basisSchluessel, { name: 'AES-GCM', length: 256 }, false, ['decrypt']);
    try {
      const roh = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: ausBase64(fach.iv), additionalData: kodierer.encode('adk-kurs:' + kennung) },
        kek, ausBase64(fach.daten));
      return new Uint8Array(roh);
    } catch (e) {
      throw grundFehler('falsch');
    }
  }
  function alsSchluessel(roh) { return crypto.subtle.importKey('raw', roh, 'AES-GCM', false, ['decrypt']); }
  /* Kennung des Kursschlüssels, wie bauen.mjs sie in zugang.json schreibt:
     HMAC-SHA256(K, „adk-kurs-schluessel“), die ersten 8 Byte als Hex */
  async function schluesselKennung(roh) {
    const hmac = await crypto.subtle.importKey('raw', roh, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const mac = await crypto.subtle.sign('HMAC', hmac, kodierer.encode('adk-kurs-schluessel'));
    return alsHex(new Uint8Array(mac)).slice(0, 16);
  }
  async function entschluessele(schluessel, puffer) {
    const b = new Uint8Array(puffer);
    if (b[0] !== 1) throw new Error('Unbekanntes Datenformat');
    return crypto.subtle.decrypt({ name: 'AES-GCM', iv: b.subarray(1, 13) }, schluessel, b.subarray(13));
  }

  /* ── Laden ─────────────────────────────────────────────────────────────── */
  async function holeJson(url) {
    const r = await fetch(url, { cache: 'no-cache' });
    if (!r.ok) throw new Error('HTTP ' + r.status + ' bei ' + url);
    return r.json();
  }
  async function holeBinaer(url, frisch) {
    const r = await fetch(url, frisch ? { cache: 'no-cache' } : undefined);
    if (!r.ok) throw new Error('HTTP ' + r.status + ' bei ' + url);
    return r.arrayBuffer();
  }

  /* Mit einem eingegebenen Code anmelden. Wirft Fehler mit .grund:
     form (kein gültiger Code), unbekannt (kein Fach), falsch (Fach passt nicht),
     speicher (der Browser lässt nichts speichern – dann gälte der Zugang nur
     auf dieser einen Seite, und jede Lektion schickte zurück zum Code). */
  async function anmelden(eingabe, dauerhaft) {
    const code = normalisiere(eingabe);
    if (!code) throw grundFehler('form');
    const zugang = await holeJson(new URL('daten/zugang.json', basis));
    const roh = await oeffneFach(code, zugang);
    abmelden();
    const gemerkt = schreib(dauerhaft ? 'localStorage' : 'sessionStorage', SPEICHER_CODE, code)
      && schreib('sessionStorage', SPEICHER_SCHLUESSEL, zuBase64(roh));
    if (!gemerkt) {
      abmelden();
      throw grundFehler('speicher');
    }
  }

  /* Kursschlüssel für diese Sitzung; null heißt: kein (gültiger) Zugang auf
     diesem Gerät. Jeder Aufruf gleicht mit der aktuellen zugang.json ab:
     Fehlt das Fach, ist der Code gesperrt. Passt die Schlüsselkennung nicht,
     gibt es einen neuen Kursschlüssel, und der gemerkte Code öffnet sein Fach
     neu – ein alter Sitzungsschlüssel bleibt so nicht hängen. */
  async function schluessel() {
    const code = gemerkterCode();
    if (!code) return null;
    const zugang = await holeJson(new URL('daten/zugang.json', basis));
    if (!zugang.faecher || !zugang.faecher[code.slice(0, 4)]) {
      vergiss();
      return null;
    }
    let roh = null;
    try { roh = ausBase64(lies('sessionStorage', SPEICHER_SCHLUESSEL) || ''); } catch (e) { /* kaputt: neu öffnen */ }
    if (roh && roh.length === 32 && await schluesselKennung(roh) === zugang.schluessel) return alsSchluessel(roh);
    loesch('sessionStorage', SPEICHER_SCHLUESSEL);
    try {
      roh = await oeffneFach(code, zugang);
    } catch (e) {
      if (e.grund) { vergiss(); return null; }
      throw e;
    }
    schreib('sessionStorage', SPEICHER_SCHLUESSEL, zuBase64(roh));
    return alsSchluessel(roh);
  }

  async function ladeDatei(k, name) {
    return entschluessele(k, await holeBinaer(new URL('daten/' + name, basis)));
  }

  /* Kursaufbau laden. Klartext: kurs.json aus /onlinekurs/. Sonst kurs.bin
     entschlüsseln; null, wenn auf diesem Gerät kein Zugang besteht. */
  async function ladeKurs() {
    if (klartext) return holeJson(new URL('kurs.json', QUELLE));
    if (!gemerkterCode()) return null;
    const geladen = await Promise.all([schluessel(), holeBinaer(new URL('daten/kurs.bin', basis), true)]);
    const k = geladen[0];
    if (!k) return null;
    const kurs = JSON.parse(new TextDecoder().decode(await entschluessele(k, geladen[1])));
    kurs.schluessel = k;
    return kurs;
  }

  function alleLektionen(kurs) {
    const liste = [];
    kurs.module.forEach(function (modul) {
      modul.lektionen.forEach(function (l) { liste.push(Object.assign({ modul: modul }, l)); });
    });
    return liste;
  }

  /* ── Lektionen ─────────────────────────────────────────────────────────── */
  /* Eigene Dateien einer Lektion stehen relativ in src, data-ton oder poster,
     auch in <template>. Mit „/“ vorn (etwa /assets/…) sind es Dateien der
     Website; sie bleiben stehen. Dieselbe Regel steht in werkzeuge/gemeinsam.mjs. */
  const VERWEISE = ['src', 'data-ton', 'poster'];
  function eigeneDatei(wert) { return !!wert && !/^(?:[a-z][a-z0-9+.-]*:|[/#])/i.test(wert); }
  function jederVerweis(wurzel, tu) {
    wurzel.querySelectorAll('[src], [data-ton], [poster]').forEach(function (el) {
      VERWEISE.forEach(function (attr) {
        const wert = el.getAttribute(attr);
        if (eigeneDatei(wert)) tu(el, attr, wert);
      });
    });
    wurzel.querySelectorAll('template').forEach(function (t) { jederVerweis(t.content, tu); });
  }
  function verweise(wurzel) {
    const namen = new Set();
    jederVerweis(wurzel, function (el, attr, wert) { namen.add(wert); });
    return Array.from(namen);
  }
  function lektionsOrdner(lektion) {
    return new URL(String(lektion.ordner).replace(/\/?$/, '/'), QUELLE);
  }

  /* Der Ausschnitt einer Lektion als <article class="lektion">, noch außerhalb
     des Dokuments; null, wenn es ihn (noch) nicht gibt. */
  async function ladeArtikel(kurs, lektion) {
    let html;
    if (klartext) {
      const antwort = await fetch(new URL('inhalt.html', lektionsOrdner(lektion)), { cache: 'no-cache' });
      if (antwort.status === 404) return null;
      if (!antwort.ok) throw new Error('HTTP ' + antwort.status + ' für ' + lektion.ordner + '/inhalt.html');
      html = await antwort.text();
    } else {
      if (!lektion.inhalt) return null;
      html = new TextDecoder().decode(await ladeDatei(kurs.schluessel, lektion.inhalt));
    }
    const vorlage = document.createElement('template');
    vorlage.innerHTML = html;
    return vorlage.content.querySelector('article.lektion');
  }

  /* Adressen der eigenen Dateien als aufloesen(rel): im Klartext die
     Quelldatei, sonst entschlüsselt als Blob-URL – alle Dateien der Lektion
     (namen = null) oder nur die genannten. weiter() meldet jede fertige Datei. */
  async function dateien(kurs, lektion, namen, weiter) {
    if (klartext) {
      const ordner = lektionsOrdner(lektion);
      return function (rel) { return new URL(rel, ordner).href; };
    }
    const medien = lektion.medien || {};
    const adressen = Object.create(null);
    await Promise.all((namen || Object.keys(medien)).filter(function (rel) { return medien[rel]; }).map(async function (rel) {
      const daten = await ladeDatei(kurs.schluessel, medien[rel].blob);
      adressen[rel] = URL.createObjectURL(new Blob([daten], { type: medien[rel].typ }));
      if (weiter) weiter();
    }));
    return function (rel) { return adressen[rel] || null; };
  }
  function setzeVerweise(wurzel, aufloesen) {
    jederVerweis(wurzel, function (el, attr, wert) {
      const adresse = aufloesen(wert);
      if (adresse) el.setAttribute(attr, adresse);
      else console.warn('Datei gehört nicht zur Lektion:', wert);
    });
  }

  /* ── Druckblatt füllen ─────────────────────────────────────────────────── */
  /* [data-druck] bekommt den Text eines Felds, [data-druck-wahl] markiert die
     gewählten [data-wert] (mehrere Häkchen stehen mit | im Wert). Liefert,
     wie viele Stellen das Blatt hat und wie viele davon ausgefüllt sind. */
  function fuelleDruckblatt(wurzel, wertVon) {
    let gesamt = 0;
    let ausgefuellt = 0;
    wurzel.querySelectorAll('[data-druck]').forEach(function (d) {
      const v = String(wertVon(d.dataset.druck) || '').trim();
      d.textContent = v;
      d.classList.toggle('leer', !v);
      gesamt += 1;
      if (v) ausgefuellt += 1;
    });
    wurzel.querySelectorAll('[data-druck-wahl]').forEach(function (d) {
      const gewaehlt = String(wertVon(d.dataset.druckWahl) || '').split('|');
      let irgendeins = false;
      d.querySelectorAll('[data-wert]').forEach(function (s) {
        const an = gewaehlt.indexOf(s.dataset.wert) !== -1;
        s.classList.toggle('gewaehlt', an);
        irgendeins = irgendeins || an;
      });
      gesamt += 1;
      if (irgendeins) ausgefuellt += 1;
    });
    return { gesamt: gesamt, ausgefuellt: ausgefuellt };
  }

  /* ── Bausteine ─────────────────────────────────────────────────────────── */
  function element(tag, klasse, text) {
    const el = document.createElement(tag);
    if (klasse) el.className = klasse;
    if (text !== undefined && text !== null) el.textContent = text;
    return el;
  }
  function symbol(name) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'symbol');
    svg.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', '#' + name);
    svg.appendChild(use);
    return svg;
  }
  /* „3-Schritte-Plan“ nicht nach „3-“ umbrechen: Strich hinter einer Ziffer
     wird zum geschützten Bindestrich (U+2011) */
  function ohneUmbruch(text) { return String(text).replace(/(\d)-/g, '$1' + String.fromCharCode(0x2011)); }
  /* Fehlerkasten: Überschrift, Erklärung und der Weg zurück zur Übersicht */
  function fuelleFehler(kasten, titel, text) {
    kasten.textContent = '';
    kasten.appendChild(element('h1', '', titel));
    kasten.appendChild(element('p', '', text));
    const zurueck = element('a', 'knopf knopf-geist', 'Zur Kursübersicht');
    zurueck.href = uebersichtsLink();
    kasten.appendChild(zurueck);
  }
  /* Links mit data-zur-uebersicht und data-zum-arbeitsheft auf ihr Ziel setzen
     (im Klartext-Modus mit ?klartext) */
  function verlinke(wurzel) {
    wurzel.querySelectorAll('[data-zur-uebersicht]').forEach(function (a) { a.href = uebersichtsLink(); });
    wurzel.querySelectorAll('[data-zum-arbeitsheft]').forEach(function (a) { a.href = arbeitsheftLink(); });
  }
  /* Rückkehr aus dem Back-Forward-Cache: Die Seite kommt eingefroren wieder,
     ohne neu zu laden – Fortschritt und Anmeldung können sich inzwischen
     geändert haben. */
  function beiRueckkehr(tu) {
    window.addEventListener('pageshow', function (ev) { if (ev.persisted) tu(); });
  }

  /* ── Links ─────────────────────────────────────────────────────────────── */
  function lektionsLink(id) {
    return new URL('lektion/?id=' + encodeURIComponent(id) + (klartext ? '&klartext' : ''), basis).href;
  }
  function arbeitsheftLink() {
    return new URL('arbeitsheft/' + (klartext ? '?klartext' : ''), basis).href;
  }
  function uebersichtsLink(ziel) {
    const teile = [];
    if (klartext) teile.push('klartext');
    if (ziel) teile.push('ziel=' + encodeURIComponent(ziel));
    return new URL(teile.length ? './?' + teile.join('&') : './', basis).href;
  }

  window.Kurs = {
    KURS: KURS,
    klartext: klartext,
    PRAEFIX: PRAEFIX,
    verfuegbar: verfuegbar,
    normalisiere: normalisiere,
    formatiere: formatiere,
    hatCode: function () { return !!gemerkterCode(); },
    hinweisAbholen: hinweisAbholen,
    anmelden: anmelden,
    abmelden: abmelden,
    ladeKurs: ladeKurs,
    alleLektionen: alleLektionen,
    ladeArtikel: ladeArtikel,
    dateien: dateien,
    verweise: verweise,
    setzeVerweise: setzeVerweise,
    fuelleDruckblatt: fuelleDruckblatt,
    ablage: ablage,
    feldSchluessel: feldSchluessel,
    element: element,
    symbol: symbol,
    ohneUmbruch: ohneUmbruch,
    fuelleFehler: fuelleFehler,
    verlinke: verlinke,
    beiRueckkehr: beiRueckkehr,
    lektionsLink: lektionsLink,
    arbeitsheftLink: arbeitsheftLink,
    uebersichtsLink: uebersichtsLink
  };
})();
