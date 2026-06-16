/* ===========================================================================
 * i18n-add-federacao-assembleias-firstpoint-facilitation.cjs
 * Onglet Assemblées — 4ᵉ point pressenti : federacao.assembleias.firstPoints.facilitation
 * (instituer la facilitation) dans les 10 locales. Insertion idempotente.
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.assembleias.firstPoints.facilitation';

const ADD = {
  'pt-BR': { "federacao.assembleias.firstPoints.facilitation": "Instituir a facilitação: criar o papel de facilitação e designar quem animará as próximas assembleias — para que a animação passe dos admins da rede aos coletivos." },
  fr: { "federacao.assembleias.firstPoints.facilitation": "Instituer la facilitation : créer le rôle de facilitateur·rice et désigner qui animera les assemblées suivantes — pour que l’animation passe des admins réseau aux collectifs." },
  es: { "federacao.assembleias.firstPoints.facilitation": "Instituir la facilitación: crear el rol de facilitación y designar quién animará las próximas asambleas — para que la animación pase de los admins de la red a los colectivos." },
  en: { "federacao.assembleias.firstPoints.facilitation": "Institute facilitation: create the facilitation role and designate who will run the next assemblies — so that running them passes from network admins to the collectives." },
  it: { "federacao.assembleias.firstPoints.facilitation": "Istituire la facilitazione: creare il ruolo di facilitazione e designare chi animerà le prossime assemblee — perché l’animazione passi dagli admin della rete ai collettivi." },
  de: { "federacao.assembleias.firstPoints.facilitation": "Die Moderation einrichten: die Moderationsrolle schaffen und bestimmen, wer die nächsten Versammlungen leitet — damit die Leitung von den Netzwerk-Admins zu den Kollektiven übergeht." },
  ca: { "federacao.assembleias.firstPoints.facilitation": "Instituir la facilitació: crear el rol de facilitació i designar qui animarà les assemblees següents — perquè l’animació passi dels admins de la xarxa als col·lectius." },
  eo: { "federacao.assembleias.firstPoints.facilitation": "Establi la faciligadon: krei la rolon de faciliganto kaj difini kiu gvidos la sekvajn asembleojn — por ke la animado transiru de la ret-administrantoj al la kolektivoj." },
  nl: { "federacao.assembleias.firstPoints.facilitation": "De facilitatie instellen: de facilitatierol creëren en aanwijzen wie de volgende vergaderingen leidt — zodat het leiden overgaat van de netwerkbeheerders naar de collectieven." },
  el: { "federacao.assembleias.firstPoints.facilitation": "Θέσπιση της διευκόλυνσης: δημιουργία του ρόλου διευκόλυνσης και ορισμός του ποιος θα συντονίζει τις επόμενες συνελεύσεις — ώστε ο συντονισμός να περάσει από τους διαχειριστές του δικτύου στις συλλογικότητες." }
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': firstPoints.facilitation (si absent), JSON valide.');
}
console.log('\nTerminé.');
