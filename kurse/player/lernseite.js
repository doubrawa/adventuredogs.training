/* Lernseite – Abspieler für die Lektionen des Onlinekurses.

   Die Seite kurse/<kurs>/lektion/ lädt eine Lektion (im Klartext oder entschlüsselt),
   setzt sie in <main class="buehne"> ein und ruft dann
   Lernseite.starte(<Kennung der Lektion>).

   Jede <section class="schritt"> ist ein Schritt; der erste ist das
   Deckblatt. data-art bestimmt die Rolle:
     titel      Deckblatt, ohne Steuerleiste
     hoeren     Bild und Ton; ist der Ton zu Ende, geht es von selbst weiter
     uebung     Mitmachen; wartet, bis man selbst auf „Weiter“ tippt
     abschluss  letzter Schritt
   data-ton nennt die Aufnahme, <p class="sprechtext"> den Text dazu. Derselbe
   Text läuft als Untertitel mit; die Platzhalterstimme liest ihn ebenfalls.

   Übungen: data-uebung="foto" (Stellen im Foto antippen), "faelle" (Fälle
   einschätzen), "plan" (Felder und Druckblatt); dazu die Bausteine
   .auswahl (Mehrfachauswahl), .aufdecken (Karten umdrehen) und
   .reihenfolge (Schritte in die richtige Folge tippen).

   Alles, was jemand eingibt, bleibt im localStorage dieses Geräts (Schema in
   kurs.js). Die Seite schickt nichts weg. */
(function () {
  'use strict';

  function starte(lektion) {
    const doc = document;
    const body = doc.body;
    const Kurs = window.Kurs;
    const speicher = Kurs.ablage(lektion + ':');          // Fortschritt und Übungsstände dieser Lektion
    const einstellungen = Kurs.ablage('einstellungen:');  // Tempo, Untertitel, automatisch weiter: für den ganzen Kurs
    const geraet = Kurs.ablage('');                       // Felder, Schlüssel über Kurs.feldSchluessel

    if (new URLSearchParams(location.search).has('pruefen')) doc.documentElement.classList.add('pruefen');

    /* Ergebnis einer Übung ins Bild holen (Abstand zu Kopf und Leiste per scroll-margin) */
    const wenigBewegung = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    function insBild(el) {
      if (!el) return;
      requestAnimationFrame(function () { el.scrollIntoView({ block: 'nearest', behavior: wenigBewegung ? 'auto' : 'smooth' }); });
    }

    /* ── Vorlagen einsetzen: eine Szene, mehrere Aufbaustufen ──────────────── */
    doc.querySelectorAll('[data-vorlage]').forEach(function (platz) {
      const vorlage = doc.getElementById(platz.dataset.vorlage);
      if (!vorlage) return;
      platz.appendChild(vorlage.content.cloneNode(true));
      const schritt = platz.closest('.schritt');
      const stufe = Number((schritt && schritt.dataset.stufe) || 99);
      platz.querySelectorAll('[data-stufe]').forEach(function (el) {
        const s = Number(el.dataset.stufe);
        el.classList.toggle('verborgen', s > stufe);
        el.classList.toggle('neu', s === stufe);
      });
    });

    /* ── Schritte und Steuerung ────────────────────────────────────────────── */
    const $ = function (id) { return doc.getElementById(id); };
    const schritte = Array.from(doc.querySelectorAll('.schritt'));
    const letzter = schritte.length - 1;
    const leiste = $('fortschritt');
    const zaehler = $('zaehler');
    const untertitel = $('untertitel');
    const ansage = $('ansage');
    const steuerung = $('steuerung');
    const knopfZurueck = $('zurueck');
    const knopfWeiter = $('weiter');
    const knopfSpielen = $('spielen');
    const knopfText = $('text-schalter');
    const knopfOptionen = $('optionen-knopf');
    const optionen = $('optionen');
    const autoSchalter = $('automatisch');
    const regler = $('regler');
    const zeitJetzt = $('zeit-jetzt');
    const zeitGesamt = $('zeit-gesamt');

    let aktuell = -1;
    let wiedergabe = false;      // läuft die Lektion „mit Ton“? Pause schaltet das ab
    let weiterTimer = 0;
    let suchtGerade = false;
    let tempo = Number(einstellungen.lesen('tempo', 1)) || 1;
    let automatisch = einstellungen.lesen('automatisch', true) !== false;
    speicher.schreiben('anzahl', letzter);

    /* Übungsstände hängen am Titel des Schritts, nicht an seiner Nummer: Kommt
       später ein Schritt dazu, bleibt jeder Stand bei seiner Übung. Titel sind
       je Lektion eindeutig (pruefen.mjs warnt sonst). */
    function kennung(schritt) { return schritt.dataset.titel || 'schritt-' + schritte.indexOf(schritt); }

    leiste.textContent = '';
    schritte.slice(1).forEach(function (s, i) {
      const b = doc.createElement('button');
      b.type = 'button';
      b.title = (i + 1) + '. ' + (s.dataset.titel || '');
      b.setAttribute('aria-label', 'Schritt ' + (i + 1) + ' von ' + letzter + ': ' + (s.dataset.titel || ''));
      b.addEventListener('click', function () { zeige(i + 1); });
      leiste.appendChild(b);
    });

    /* ── Ton ───────────────────────────────────────────────────────────────── */
    const ton = new Audio();
    ton.preload = 'auto';

    function uhr(sek) {
      if (!isFinite(sek) || sek < 0) sek = 0;
      const m = Math.floor(sek / 60);
      const s = Math.floor(sek % 60);
      return m + ':' + (s < 10 ? '0' : '') + s;
    }
    function zeigeZeit() {
      const d = ton.duration;
      zeitJetzt.textContent = uhr(ton.currentTime);
      zeitGesamt.textContent = isFinite(d) ? uhr(d) : '0:00';
      if (!suchtGerade) {
        regler.max = isFinite(d) ? String(d) : '0';
        regler.value = String(ton.currentTime);
      }
    }
    function setzeSpielt(an) {
      knopfSpielen.classList.toggle('spielt', an);
      knopfSpielen.setAttribute('aria-label', an ? 'Pause' : 'Abspielen');
    }
    function spiele() {
      const versuch = ton.play();
      if (versuch && versuch.catch) versuch.catch(function () { setzeSpielt(false); });
    }
    function ladeTon(schritt) {
      clearTimeout(weiterTimer);
      body.classList.remove('ton-fertig');
      ton.pause();
      const quelle = schritt.dataset.ton;
      steuerung.classList.toggle('ohne-ton', !quelle);
      if (!quelle) {
        ton.removeAttribute('src');
        ton.load();
        zeigeZeit();
        setzeSpielt(false);
        return;
      }
      ton.src = quelle;
      ton.defaultPlaybackRate = tempo;
      ton.playbackRate = tempo;
      zeigeZeit();
      if (wiedergabe) spiele();
    }

    ton.addEventListener('play', function () { setzeSpielt(true); body.classList.remove('ton-fertig'); });
    ton.addEventListener('pause', function () { setzeSpielt(false); });
    ton.addEventListener('timeupdate', zeigeZeit);
    ton.addEventListener('loadedmetadata', zeigeZeit);
    ton.addEventListener('durationchange', zeigeZeit);
    ton.addEventListener('ended', function () {
      setzeSpielt(false);
      body.classList.add('ton-fertig');
      const s = schritte[aktuell];
      if (automatisch && s && s.dataset.art === 'hoeren' && aktuell < letzter) {
        weiterTimer = setTimeout(function () { zeige(aktuell + 1); }, 1200);
      }
    });
    ton.addEventListener('error', function () {
      if (!ton.getAttribute('src')) return;
      zeitJetzt.textContent = 'Aufnahme fehlt';
      zeitGesamt.textContent = '';
    });

    knopfSpielen.addEventListener('click', function () {
      clearTimeout(weiterTimer);
      if (!ton.getAttribute('src')) return;
      if (ton.paused) { wiedergabe = true; spiele(); } else { wiedergabe = false; ton.pause(); }
    });
    regler.addEventListener('input', function () {
      suchtGerade = true;
      clearTimeout(weiterTimer);
      ton.currentTime = Number(regler.value);
      zeigeZeit();
    });
    /* Ende des Ziehens. change allein reicht nicht: Es kommt nicht, wenn der
       Regler wieder auf seinem Anfangswert landet, und dann stünde er still. */
    function suchenEnde() { suchtGerade = false; }
    regler.addEventListener('change', suchenEnde);
    regler.addEventListener('blur', suchenEnde);
    doc.addEventListener('pointerup', suchenEnde);
    doc.addEventListener('pointercancel', suchenEnde);

    /* ── Optionen: Tempo und „automatisch weiter“ ──────────────────────────── */
    function zeigeOptionen() {
      optionen.querySelectorAll('[data-tempo]').forEach(function (b) {
        b.setAttribute('aria-pressed', String(Number(b.dataset.tempo) === tempo));
      });
      autoSchalter.checked = automatisch;
      knopfOptionen.dataset.tempo = tempo === 1 ? '' : String(tempo).replace('.', ',') + '×';
    }
    optionen.querySelectorAll('[data-tempo]').forEach(function (b) {
      b.addEventListener('click', function () {
        tempo = Number(b.dataset.tempo);
        ton.defaultPlaybackRate = tempo;
        ton.playbackRate = tempo;
        einstellungen.schreiben('tempo', tempo);
        zeigeOptionen();
      });
    });
    autoSchalter.addEventListener('change', function () {
      automatisch = autoSchalter.checked;
      einstellungen.schreiben('automatisch', automatisch);
      if (!automatisch) clearTimeout(weiterTimer);
    });
    function platziereOptionen() {
      const r = knopfOptionen.getBoundingClientRect();
      const breite = optionen.offsetWidth;
      const links = Math.min(window.innerWidth - breite - 12, Math.max(12, r.right - breite));
      optionen.style.left = links + 'px';
      optionen.style.top = 'auto';
      optionen.style.bottom = (window.innerHeight - r.top + 10) + 'px';
    }
    if ('popover' in HTMLElement.prototype) {
      optionen.addEventListener('toggle', function (ev) {
        knopfOptionen.setAttribute('aria-expanded', String(ev.newState === 'open'));
        if (ev.newState === 'open') platziereOptionen();
      });
    } else {
      /* Ohne Popover-API (ältere Browser): selbst auf- und zuklappen */
      knopfOptionen.addEventListener('click', function () {
        const offen = optionen.classList.toggle('offen');
        optionen.style.display = offen ? 'block' : '';
        knopfOptionen.setAttribute('aria-expanded', String(offen));
        if (offen) platziereOptionen();
      });
    }
    zeigeOptionen();

    /* ── Untertitel ein/aus ────────────────────────────────────────────────── */
    function setzeText(an) {
      body.classList.toggle('ohne-text', !an);
      knopfText.setAttribute('aria-pressed', String(an));
      einstellungen.schreiben('text', an);
    }
    knopfText.addEventListener('click', function () { setzeText(body.classList.contains('ohne-text')); });
    setzeText(einstellungen.lesen('text', true) !== false);

    /* ── Schritt zeigen ────────────────────────────────────────────────────── */
    function zeige(n) {
      n = Math.max(0, Math.min(letzter, n));
      if (n === aktuell) return;
      const vorher = schritte[aktuell];
      const neu = schritte[n];
      const gleicheSzene = !!(vorher && vorher.dataset.szene && vorher.dataset.szene === neu.dataset.szene);
      const fokusWarDrin = !!(vorher && vorher.contains(doc.activeElement));

      if (vorher) vorher.classList.remove('aktiv');
      neu.classList.toggle('ohne-auftritt', gleicheSzene);
      neu.classList.add('aktiv');
      aktuell = n;
      body.dataset.art = neu.dataset.art || 'hoeren';

      Array.from(leiste.children).forEach(function (b, i) {
        b.classList.toggle('erledigt', i + 1 < n);
        b.classList.toggle('aktuell', i + 1 === n);
        if (i + 1 === n) b.setAttribute('aria-current', 'step'); else b.removeAttribute('aria-current');
      });
      zaehler.textContent = n ? 'Schritt ' + n + ' von ' + letzter : letzter + ' Schritte';

      const sprech = neu.querySelector('.sprechtext');
      untertitel.textContent = sprech ? sprech.textContent.replace(/\s+/g, ' ').trim() : '';
      untertitel.scrollTop = 0;
      if (sprech && sprech.dataset.herkunft) untertitel.dataset.herkunft = sprech.dataset.herkunft;
      else delete untertitel.dataset.herkunft;

      knopfZurueck.disabled = n === 0;
      knopfWeiter.disabled = n === letzter;
      if (n > 0) speicher.schreiben('schritt', n);
      if (n === letzter) speicher.schreiben('fertig', true);
      try { history.replaceState(null, '', n ? '#schritt-' + n : location.pathname + location.search); } catch (e) { /* file:// */ }

      ladeTon(neu);
      window.scrollTo(0, 0);
      if (fokusWarDrin) {
        const kopf = neu.querySelector('h1, h2');
        if (kopf) { kopf.tabIndex = -1; kopf.focus({ preventScroll: true }); }
      }
      ansage.textContent = n ? 'Schritt ' + n + ' von ' + letzter + ': ' + (neu.dataset.titel || '') : '';
    }

    knopfWeiter.addEventListener('click', function () { zeige(aktuell + 1); });
    knopfZurueck.addEventListener('click', function () { zeige(aktuell - 1); });
    doc.querySelectorAll('[data-start]').forEach(function (b) {
      b.addEventListener('click', function () { wiedergabe = true; zeige(Number(b.dataset.start) || 1); });
    });
    doc.querySelectorAll('[data-gehe]').forEach(function (b) {
      b.addEventListener('click', function () { zeige(Number(b.dataset.gehe)); });
    });
    doc.addEventListener('keydown', function (ev) {
      if (ev.defaultPrevented || ev.altKey || ev.ctrlKey || ev.metaKey) return;
      if (ev.target.closest('input, textarea, select, [contenteditable]')) return;
      if (ev.key === 'ArrowRight') { ev.preventDefault(); zeige(aktuell + 1); }
      else if (ev.key === 'ArrowLeft') { ev.preventDefault(); zeige(aktuell - 1); }
      else if ((ev.key === ' ' || ev.key === 'k') && !ev.target.closest('button, a, summary')) {
        ev.preventDefault();
        knopfSpielen.click();
      }
    });
    window.addEventListener('hashchange', function () {
      const treffer = /^#schritt-(\d+)$/.exec(location.hash);
      if (treffer) zeige(Number(treffer[1]));
    });

    /* ── Übung: Was siehst du? ─────────────────────────────────────────────── */
    doc.querySelectorAll('[data-uebung="foto"]').forEach(function (schritt) {
      const schluessel = 'foto:' + kennung(schritt);
      const foto = schritt.querySelector('.foto');
      const punkte = Array.from(schritt.querySelectorAll('.foto-punkt'));
      const befunde = Array.from(schritt.querySelectorAll('.foto-befund'));
      const stand = schritt.querySelector('.foto-stand');
      const hinweis = schritt.querySelector('.foto-hinweis');
      const fazit = schritt.querySelector('.fazit');
      const aufloesen = schritt.querySelector('[data-aufloesen]');
      const nochmal = schritt.querySelector('[data-foto-neu]');
      const namen = punkte.map(function (p) { return p.dataset.punkt; });
      const gemerkt = speicher.lesen(schluessel, []);
      const gefunden = new Set((Array.isArray(gemerkt) ? gemerkt : []).filter(function (p) { return namen.indexOf(p) !== -1; }));

      function darstellen() {
        punkte.forEach(function (p) {
          const ja = gefunden.has(p.dataset.punkt);
          p.classList.toggle('gefunden', ja);
          p.setAttribute('aria-label', ja ? 'Gefunden: ' + p.dataset.name : 'Diese Stelle prüfen');
        });
        befunde.forEach(function (b) { b.classList.toggle('gefunden', gefunden.has(b.dataset.punkt)); });
        stand.textContent = gefunden.size + ' von ' + punkte.length + ' gefunden';
        const alle = gefunden.size === punkte.length;
        if (fazit) fazit.hidden = !alle;
        if (aufloesen) aufloesen.hidden = alle;
        if (nochmal) nochmal.hidden = gefunden.size === 0;
      }
      function merken() { speicher.schreiben(schluessel, Array.from(gefunden)); }

      punkte.forEach(function (p) {
        p.addEventListener('click', function (ev) {
          ev.stopPropagation();
          if (gefunden.has(p.dataset.punkt)) { hinweis.textContent = 'Die hast du schon.'; return; }
          gefunden.add(p.dataset.punkt);
          merken();
          hinweis.textContent = gefunden.size === punkte.length ? 'Alle gefunden.' : 'Gut gesehen.';
          darstellen();
          if (gefunden.size === punkte.length) insBild(fazit);
        });
      });
      foto.addEventListener('click', function (ev) {
        if (ev.target.closest('.foto-punkt')) return;
        const r = foto.getBoundingClientRect();
        const kreis = doc.createElement('span');
        kreis.className = 'foto-fehl';
        kreis.style.left = (ev.clientX - r.left) + 'px';
        kreis.style.top = (ev.clientY - r.top) + 'px';
        foto.appendChild(kreis);
        setTimeout(function () { kreis.remove(); }, 700);
        hinweis.textContent = 'Hier nicht. Probier eine andere Stelle.';
      });
      if (aufloesen) aufloesen.addEventListener('click', function () {
        punkte.forEach(function (p) { gefunden.add(p.dataset.punkt); });
        merken();
        hinweis.textContent = '';
        darstellen();
        insBild(fazit);
      });
      if (nochmal) nochmal.addEventListener('click', function () {
        gefunden.clear();
        merken();
        hinweis.textContent = '';
        darstellen();
      });
      darstellen();
    });

    /* ── Übung: Fälle einschätzen (zwei oder mehr Antworten) ───────────────── */
    doc.querySelectorAll('[data-uebung="faelle"]').forEach(function (schritt) {
      const schluessel = 'faelle:' + kennung(schritt);
      const faelle = Array.from(schritt.querySelectorAll('.fall'));
      const ergebnis = schritt.querySelector('.ergebnis');
      const zahl = schritt.querySelector('[data-punkte]');
      const bewertung = schritt.querySelector('[data-bewertung]');
      const knopfNaechster = schritt.querySelector('[data-naechster]');
      const knopfNeu = schritt.querySelector('[data-faelle-neu]');

      function antwortKnopf(fall, wert) {
        return Array.from(fall.querySelectorAll('[data-antwort]')).find(function (k) { return k.dataset.antwort === wert; });
      }
      /* Gemerkte Antworten nur, soweit sie zu den Fällen passen, wie sie jetzt dastehen */
      let antworten = speicher.lesen(schluessel, []);
      if (!Array.isArray(antworten)) antworten = [];
      let gueltig = 0;
      while (gueltig < antworten.length && gueltig < faelle.length && antwortKnopf(faelle[gueltig], antworten[gueltig])) gueltig += 1;
      antworten = antworten.slice(0, gueltig);
      let index = antworten.length;

      function darstellen() {
        faelle.forEach(function (f, i) {
          f.hidden = i !== index;
          const gewaehlt = antworten[i];
          f.querySelectorAll('[data-antwort]').forEach(function (k) {
            k.disabled = !!gewaehlt;
            k.classList.toggle('gewaehlt', k.dataset.antwort === gewaehlt);
          });
          const rm = f.querySelector('.rueckmeldung');
          rm.hidden = !gewaehlt;
          if (gewaehlt) {
            const richtig = gewaehlt === f.dataset.richtig;
            rm.classList.toggle('richtig', richtig);
            rm.classList.toggle('falsch', !richtig);
            rm.querySelector('.urteil').textContent = richtig ? 'Genau.' : 'Nicht ganz.';
            rm.querySelector('.urteil-symbol use').setAttribute('href', richtig ? '#i-haken' : '#i-info');
          }
        });
        const fertig = index >= faelle.length;
        ergebnis.hidden = !fertig;
        knopfNaechster.hidden = fertig || !antworten[index];
        knopfNaechster.querySelector('span').textContent = index === faelle.length - 1 ? 'Zur Auswertung' : 'Nächster Fall';
        if (fertig) {
          const richtige = faelle.filter(function (f, i) { return antworten[i] === f.dataset.richtig; }).length;
          zahl.textContent = String(richtige);
          bewertung.textContent = richtige === faelle.length ? bewertung.dataset.alle : bewertung.dataset.teils;
          zeigeAuswertung();
        }
      }

      /* Je Fall eine Zeile; wo die Einschätzung danebenlag, die Erklärung dazu */
      function zeigeAuswertung() {
        const liste = ergebnis.querySelector('.auswertung');
        if (!liste) return;
        liste.textContent = '';
        faelle.forEach(function (f, i) {
          const richtig = antworten[i] === f.dataset.richtig;
          const knopf = antwortKnopf(f, f.dataset.richtig);
          const loesung = (knopf.querySelector('strong') || knopf).textContent.trim();
          const zeile = doc.createElement('li');
          zeile.className = richtig ? 'richtig' : 'falsch';
          const kopf = doc.createElement('strong');
          kopf.textContent = 'Fall ' + (i + 1) + ': ' + (richtig ? 'richtig eingeschätzt' : 'richtig wäre „' + loesung + '“');
          zeile.appendChild(kopf);
          if (!richtig) {
            const erklaerung = doc.createElement('span');
            erklaerung.textContent = f.querySelector('.rueckmeldung p:last-child').textContent;
            zeile.appendChild(erklaerung);
          }
          liste.appendChild(zeile);
        });
      }

      faelle.forEach(function (f, i) {
        f.querySelectorAll('[data-antwort]').forEach(function (k) {
          k.addEventListener('click', function () {
            if (antworten[i]) return;
            antworten[i] = k.dataset.antwort;
            speicher.schreiben(schluessel, antworten);
            darstellen();
            knopfNaechster.focus({ preventScroll: true });
            insBild(knopfNaechster);
          });
        });
      });
      knopfNaechster.addEventListener('click', function () {
        index += 1;
        darstellen();
        const ziel = index < faelle.length ? faelle[index].querySelector('.fall-text') : ergebnis.querySelector('.ergebnis-zahl');
        if (ziel) { ziel.tabIndex = -1; ziel.focus({ preventScroll: true }); }
        insBild(index < faelle.length ? faelle[index] : ergebnis);
      });
      knopfNeu.addEventListener('click', function () {
        antworten = [];
        index = 0;
        speicher.schreiben(schluessel, antworten);
        darstellen();
      });
      darstellen();
    });

    /* ── Gemeinsamer Ablauf von .auswahl und .reihenfolge ──────────────────── */
    /* Teile antippen (an und wieder aus, in der Reihenfolge des Tippens),
       prüfen, neu anfangen. Der Stand { wahl, geprueft } bleibt im Speicher;
       darstellen(stand, teile) malt ihn je nach Baustein. */
    function antippBaustein(box, art, teile, darstellen) {
      const schritt = box.closest('.schritt');
      const nr = Array.from(schritt.querySelectorAll('.' + art)).indexOf(box);
      const schluessel = art + ':' + kennung(schritt) + ':' + nr;
      const bedienung = {
        pruefen: box.querySelector('[data-pruefen]'),
        neu: box.querySelector('[data-neu]'),
        stand: box.querySelector('[data-stand]'),
        fazit: box.querySelector('.fazit')
      };
      function frisch() { return { wahl: [], geprueft: false }; }
      /* Gemerkter Stand nur, soweit er zu den Teilen passt, wie sie jetzt dastehen */
      function pruefe(z) {
        if (!z || !Array.isArray(z.wahl)) return frisch();
        const wahl = z.wahl.filter(function (i, pos) {
          return Number.isInteger(i) && i >= 0 && i < teile.length && z.wahl.indexOf(i) === pos;
        });
        return { wahl: wahl, geprueft: z.geprueft === true };
      }
      let zustand = pruefe(speicher.lesen(schluessel, null));
      function merken() {
        speicher.schreiben(schluessel, zustand);
        darstellen(zustand, bedienung);
      }
      teile.forEach(function (teil, i) {
        teil.addEventListener('click', function () {
          if (zustand.geprueft) return;
          const pos = zustand.wahl.indexOf(i);
          if (pos === -1) zustand.wahl.push(i); else zustand.wahl.splice(pos, 1);
          merken();
        });
      });
      if (bedienung.pruefen) bedienung.pruefen.addEventListener('click', function () {
        zustand.geprueft = true;
        merken();
        insBild(bedienung.fazit || box);
      });
      if (bedienung.neu) bedienung.neu.addEventListener('click', function () {
        zustand = frisch();
        merken();
      });
      darstellen(zustand, bedienung);
    }

    /* ── Baustein: Mehrfachauswahl (.auswahl) ──────────────────────────────── */
    doc.querySelectorAll('.auswahl').forEach(function (box) {
      const optionenListe = Array.from(box.querySelectorAll('.option'));
      antippBaustein(box, 'auswahl', optionenListe, function (z, teil) {
        let richtige = 0, gefunden = 0, daneben = 0;
        optionenListe.forEach(function (o, i) {
          const an = z.wahl.indexOf(i) !== -1;
          const richtig = o.dataset.richtig === 'ja';
          if (richtig) richtige += 1;
          if (richtig && an) gefunden += 1;
          if (!richtig && an) daneben += 1;
          o.setAttribute('aria-pressed', String(an));
          o.disabled = z.geprueft;
          o.classList.toggle('aufgeloest', z.geprueft);
          o.classList.toggle('treffer', z.geprueft && an && richtig);
          o.classList.toggle('verpasst', z.geprueft && !an && richtig);
          o.classList.toggle('daneben', z.geprueft && an && !richtig);
        });
        if (teil.stand) {
          teil.stand.textContent = z.geprueft
            ? gefunden + ' von ' + richtige + ' gefunden' + (daneben ? ', ' + daneben + ' passt nicht' : '')
            : (z.wahl.length ? z.wahl.length + ' ausgewählt' : '');
        }
        if (teil.fazit) teil.fazit.hidden = !z.geprueft;
        if (teil.pruefen) teil.pruefen.hidden = z.geprueft;
        if (teil.neu) teil.neu.hidden = !z.geprueft;
      });
    });

    /* ── Baustein: Karten aufdecken (.aufdecken) ───────────────────────────── */
    doc.querySelectorAll('.aufdecken').forEach(function (box) {
      const karten = Array.from(box.querySelectorAll('.aufdeck-karte'));
      const schritt = box.closest('.schritt');
      const stand = schritt && schritt.querySelector('[data-aufdeck-stand]');
      function zaehle() {
        if (!stand) return;
        const offen = karten.filter(function (k) { return k.classList.contains('umgedreht'); }).length;
        stand.textContent = offen + ' von ' + karten.length + ' aufgedeckt';
      }
      karten.forEach(function (karte) {
        const hinten = karte.querySelector('.aufdeck-hinten');
        karte.setAttribute('aria-expanded', 'false');
        if (hinten) hinten.setAttribute('aria-hidden', 'true');
        karte.addEventListener('click', function () {
          const auf = karte.classList.toggle('umgedreht');
          karte.setAttribute('aria-expanded', String(auf));
          if (hinten) hinten.setAttribute('aria-hidden', String(!auf));
          zaehle();
        });
      });
      zaehle();
    });

    /* ── Baustein: Reihenfolge antippen (.reihenfolge) ─────────────────────── */
    doc.querySelectorAll('.reihenfolge').forEach(function (box) {
      const liste = box.querySelector('.reihenfolge-liste');
      const ursprung = Array.from(box.querySelectorAll('.glied'));
      ursprung.forEach(function (g) {
        const nrEl = doc.createElement('span');
        nrEl.className = 'glied-nr';
        nrEl.setAttribute('aria-hidden', 'true');
        g.insertBefore(nrEl, g.firstChild);
        const hinweis = doc.createElement('span');
        hinweis.className = 'glied-hinweis';
        g.appendChild(hinweis);
      });

      antippBaustein(box, 'reihenfolge', ursprung, function (z, teil) {
        const ordnung = z.geprueft
          ? ursprung.slice().sort(function (a, b) { return Number(a.dataset.position) - Number(b.dataset.position); })
          : ursprung;
        ordnung.forEach(function (g) { liste.appendChild(g.closest('li') || g); });
        let anRichtigerStelle = 0;
        ursprung.forEach(function (g, i) {
          const platz = z.wahl.indexOf(i);
          const richtig = platz + 1 === Number(g.dataset.position);
          if (z.geprueft && richtig) anRichtigerStelle += 1;
          g.disabled = z.geprueft;
          g.classList.toggle('gewaehlt', platz !== -1);
          g.classList.toggle('richtig', z.geprueft && richtig);
          g.classList.toggle('falsch', z.geprueft && !richtig);
          g.querySelector('.glied-nr').textContent = z.geprueft ? g.dataset.position : (platz === -1 ? '' : String(platz + 1));
          g.querySelector('.glied-hinweis').textContent = z.geprueft && !richtig ? 'Du hattest Platz ' + (platz + 1) + '.' : '';
          g.setAttribute('aria-label', (g.querySelector('.glied-text') || g).textContent.trim() + (platz === -1 ? '' : ', Platz ' + (platz + 1)));
        });
        const alle = z.wahl.length === ursprung.length;
        if (teil.pruefen) { teil.pruefen.hidden = z.geprueft; teil.pruefen.disabled = !alle; }
        if (teil.neu) teil.neu.hidden = !z.geprueft && z.wahl.length === 0;
        if (teil.stand) {
          teil.stand.textContent = z.geprueft
            ? anRichtigerStelle + ' von ' + ursprung.length + ' an der richtigen Stelle'
            : z.wahl.length + ' von ' + ursprung.length + ' eingeordnet';
        }
        if (teil.fazit) teil.fazit.hidden = !z.geprueft;
      });
    });

    /* ── Felder: Innehalten und Plan teilen sich die Werte ─────────────────── */
    /* Ein Feldname mit „kurs:“ vorn gilt kursweit (Kurs.feldSchluessel): So
       taucht etwa der Auslöser aus der Einstiegslektion im Plan von 5.1 auf.
       Alle anderen Felder gehören ihrer Lektion. */
    function feldLesen(name) { return String(geraet.lesen(Kurs.feldSchluessel(lektion, name), '') || ''); }
    function feldSchreiben(name, wert) { geraet.schreiben(Kurs.feldSchluessel(lektion, name), wert); }
    function feldLoeschen(name) { geraet.loeschen(Kurs.feldSchluessel(lektion, name)); }

    const felder = Array.from(doc.querySelectorAll('[data-feld]'));
    const werte = Object.create(null);
    let merkerTimer = 0;

    function fuelle(name) {
      felder.forEach(function (f) {
        if (f.dataset.feld !== name) return;
        if (f.type === 'radio' || f.type === 'checkbox') f.checked = werte[name].split('|').indexOf(f.value) !== -1;
        else if (f.value !== werte[name]) f.value = werte[name];
      });
    }
    function druck() { Kurs.fuelleDruckblatt(doc, function (name) { return werte[name]; }); }
    function zeigeGespeichert() {
      const marken = doc.querySelectorAll('.gespeichert');
      marken.forEach(function (m) { m.classList.add('sichtbar'); });
      clearTimeout(merkerTimer);
      merkerTimer = setTimeout(function () { marken.forEach(function (m) { m.classList.remove('sichtbar'); }); }, 1800);
    }

    felder.forEach(function (f) {
      const name = f.dataset.feld;
      if (!(name in werte)) werte[name] = feldLesen(name);
    });
    Object.keys(werte).forEach(fuelle);
    felder.forEach(function (f) {
      const istWahl = f.type === 'radio' || f.type === 'checkbox';
      f.addEventListener(istWahl ? 'change' : 'input', function () {
        const name = f.dataset.feld;
        if (f.type === 'checkbox') {
          /* Mehrere Häkchen unter einem Feldnamen: Werte mit | verbunden */
          const gruppe = felder.filter(function (g) { return g.dataset.feld === name && g.type === 'checkbox' && g.closest('.schritt') === f.closest('.schritt'); });
          werte[name] = gruppe.filter(function (g) { return g.checked; }).map(function (g) { return g.value; }).join('|');
        } else {
          werte[name] = f.value;
        }
        feldSchreiben(name, werte[name]);
        fuelle(name);
        druck();
        zeigeGespeichert();
      });
    });

    /* Ein anderer Tab oder die Rückkehr aus dem Zwischenspeicher des Browsers
       kann Felder geändert haben – vor allem die kursweiten, die sich mehrere
       Lektionen teilen. Dann frisch lesen, damit kein älterer Stand einen
       neueren Eintrag überschreibt. Das Feld, in dem gerade jemand tippt, bleibt. */
    function felderNeuLesen() {
      const imFeld = doc.activeElement && doc.activeElement.dataset ? doc.activeElement.dataset.feld : undefined;
      Object.keys(werte).forEach(function (name) {
        const frisch = feldLesen(name);
        if (frisch === werte[name] || name === imFeld) return;
        werte[name] = frisch;
        fuelle(name);
      });
      druck();
    }
    window.addEventListener('storage', function (ev) {
      if (ev.key === null || (ev.key.indexOf(Kurs.PRAEFIX) === 0 && ev.key.indexOf(':feld:') !== -1)) felderNeuLesen();
    });
    Kurs.beiRueckkehr(felderNeuLesen);

    /* Leeren betrifft nur die Felder dieser Lektion. Kursweite Felder (kurs:…)
       gehören auch zum Gesamtplan in 5.1 und zu anderen Lektionen. */
    doc.querySelectorAll('[data-plan-leeren]').forEach(function (b) {
      b.addEventListener('click', function () {
        const eigene = Object.keys(werte).filter(function (name) { return name.indexOf('kurs:') !== 0; });
        const kursweit = Object.keys(werte).length - eigene.length;
        const frage = 'Die Einträge dieser Lektion löschen? Das lässt sich nicht rückgängig machen.'
          + (kursweit ? ' Was auch in deinem Gesamtplan steht, bleibt erhalten.' : '');
        if (!window.confirm(frage)) return;
        eigene.forEach(function (name) {
          werte[name] = '';
          feldLoeschen(name);
          fuelle(name);
        });
        druck();
      });
    });
    doc.querySelectorAll('[data-drucken]').forEach(function (b) {
      b.addEventListener('click', function () { felderNeuLesen(); window.print(); });
    });
    druck();

    /* ── Start ─────────────────────────────────────────────────────────────── */
    const gemerkt = Number(speicher.lesen('schritt', 0)) || 0;
    const fortsetzen = $('fortsetzen');
    if (fortsetzen && gemerkt > 1 && gemerkt <= letzter) {
      fortsetzen.hidden = false;
      fortsetzen.dataset.start = String(gemerkt);
      const nrFeld = fortsetzen.querySelector('[data-nr]');
      if (nrFeld) nrFeld.textContent = String(gemerkt);
    }
    const sprung = /^#schritt-(\d+)$/.exec(location.hash);
    zeige(sprung ? Number(sprung[1]) : 0);
  }

  window.Lernseite = { starte: starte };
})();
