/* Lektionsseite: lädt eine Lektion, setzt sie ein und startet den Abspieler.

   Aufruf: kurse/<kurs>/lektion/?id=4-1 (verschlüsselt) oder auf localhost
   kurse/<kurs>/lektion/?id=4-1&klartext (Quellen aus /onlinekurs/<kurs>/, siehe kurs.js).

   Eine Lektion ist ein HTML-Ausschnitt mit <article class="lektion">: darin
   die Schritte, Vorlagen und das Druckblatt. Laden, Entschlüsseln und das
   Umschreiben der Verweise auf eigene Dateien übernimmt kurs.js; hier wird
   die Lektion eingesetzt und der Abspieler gestartet. */
(function () {
  'use strict';

  const Kurs = window.Kurs;
  const element = Kurs.element;
  const id = new URLSearchParams(location.search).get('id');
  const buehne = document.getElementById('buehne');
  const balken = document.getElementById('laden-fortschritt');

  function fuelleNaechste(box, naechste) {
    box.textContent = '';
    const kopf = element('div');
    if (!naechste) {
      kopf.appendChild(element('p', 'klein', 'Kurs geschafft'));
      kopf.appendChild(element('strong', '', 'Das war die letzte Lektion.'));
      box.appendChild(kopf);
      return;
    }
    kopf.appendChild(element('p', 'klein', 'Nächste Lektion'));
    kopf.appendChild(element('strong', '', (naechste.nummer ? naechste.nummer + ' · ' : '') + Kurs.ohneUmbruch(naechste.titel)));
    box.appendChild(kopf);
    if (naechste.geplant && !Kurs.klartext) {
      box.appendChild(element('span', 'bald', 'bald verfügbar'));
    } else {
      const link = element('a', 'knopf knopf-primaer', 'Starten');
      link.href = Kurs.lektionsLink(naechste.id);
      box.appendChild(link);
    }
  }

  function einsetzen(artikel, lektion, liste) {
    const d = artikel.dataset;
    const name = (d.nummer ? d.nummer + ' · ' : '') + (d.titel || lektion.titel);
    document.body.dataset.lektion = d.lektion || lektion.id;
    document.title = name + ' – Onlinekurs Adventure Dogs';
    document.querySelector('.kopf-lektion').textContent = Kurs.ohneUmbruch(name);
    const vorschau = document.querySelector('.vorschau-marke');
    if (vorschau) {
      vorschau.hidden = !d.vorschau;
      if (d.vorschau) vorschau.title = d.vorschau;
    }

    const druckblatt = artikel.querySelector('.druckblatt');
    if (druckblatt) document.body.appendChild(druckblatt);
    buehne.textContent = '';
    while (artikel.firstChild) buehne.appendChild(artikel.firstChild);

    const stelle = liste.findIndex(function (l) { return l.id === lektion.id; });
    buehne.querySelectorAll('[data-naechste]').forEach(function (box) { fuelleNaechste(box, liste[stelle + 1]); });
    Kurs.verlinke(document);
  }

  function fehler(titel, text) {
    document.body.dataset.art = 'fehler';
    buehne.textContent = '';
    const kasten = element('div', 'fehler');
    Kurs.fuelleFehler(kasten, titel, text);
    buehne.appendChild(kasten);
  }
  const NETZFEHLER = 'Prüf deine Internetverbindung und versuch es gleich noch einmal.';

  async function los() {
    if (!id) return fehler('Keine Lektion gewählt', 'Wähle eine Lektion in der Kursübersicht.');
    if (!Kurs.verfuegbar()) return fehler('Dieser Browser kann den Kurs nicht öffnen', 'Bitte öffne den Kurs in einem aktuellen Browser.');

    let kurs;
    try {
      kurs = await Kurs.ladeKurs();
    } catch (e) {
      console.error(e);
      return fehler('Die Lektion ließ sich nicht laden', NETZFEHLER);
    }
    if (!kurs) { location.replace(Kurs.uebersichtsLink(id)); return; }

    const liste = Kurs.alleLektionen(kurs);
    const lektion = liste.find(function (l) { return l.id === id; });
    if (!lektion || (lektion.geplant && !Kurs.klartext)) {
      return fehler('Diese Lektion gibt es noch nicht', 'Sie ist in Arbeit. Schau bald wieder vorbei.');
    }

    let artikel;
    try {
      let fertig = 0;
      balken.max = Object.keys(lektion.medien || {}).length + 1;
      const weiter = function () { fertig += 1; balken.value = fertig; };
      /* Inhalt und Dateien gleichzeitig holen: Die Namen der Dateien stehen schon im Kursaufbau */
      const geladen = await Promise.all([
        Kurs.ladeArtikel(kurs, lektion).then(function (a) { weiter(); return a; }),
        Kurs.dateien(kurs, lektion, null, weiter)
      ]);
      artikel = geladen[0];
      if (artikel) Kurs.setzeVerweise(artikel, geladen[1]);
    } catch (e) {
      console.error(e);
      return fehler('Die Lektion ließ sich nicht laden', NETZFEHLER);
    }
    if (!artikel) return fehler('Diese Lektion gibt es noch nicht', 'Sie ist in Arbeit. Schau bald wieder vorbei.');

    try {
      einsetzen(artikel, lektion, liste);
      window.Lernseite.starte(document.body.dataset.lektion);
    } catch (e) {
      console.error(e);
      fehler('Die Lektion ließ sich nicht starten', 'Lade die Seite bitte neu. Bleibt es dabei, schreib Julia kurz, welche Lektion es war.');
    }
  }

  /* Abgemeldet und mit „Zurück“ wieder hier: Ohne diese Prüfung käme die
     entschlüsselte Lektion aus dem Zwischenspeicher des Browsers zurück. */
  Kurs.beiRueckkehr(function () {
    if (!Kurs.klartext && !Kurs.hatCode()) location.replace(Kurs.uebersichtsLink(id));
  });

  los();
})();
