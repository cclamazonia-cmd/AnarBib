#!/usr/bin/env node
/**
 * i18n-add-export-autorites.cjs — H25 (28/09/2026), revues contradictoires ;
 * revues de la fin de H27 (29/09/2026).
 *
 *  - importacoes.export.lote.formatAutorites : le libellé du format « UNIMARC
 *    Autorités » (il était en dur, en français, dans les 10 locales) ;
 *  - importacoes.export.lote.pmbHint : sous le format « UNIMARC — ISO 2709 »
 *    (le catalogue), ce qui décide de tout dans PMB — l'onglet « Exemplaires
 *    UNIMARC » (l'onglet voisin, « Notices UNIMARC », importe les notices mais
 *    ignore les 995 sans le dire), la fonction « Catégories RAMEAU », et
 *    « Oui » à « Générer les liens entre notices ? » (« Non » par défaut :
 *    mesuré au banc, 0 article rattaché sur 15) ;
 *  - importacoes.export.lote.autoritesHint : sous le format « UNIMARC
 *    Autorités », l'ordre des deux fichiers, et « Non » à « Tenir compte des
 *    notices d'autorités » dans PMB 8.1 — le formulaire de « Exemplaires
 *    UNIMARC » ne transmet pas l'origine choisie (mesuré : les auteurs sont
 *    rapprochés par nom et dates dans les deux cas ; « Oui » écrit en plus des
 *    liens vers des sources absentes).
 * Les libellés de PMB sont ceux que PMB 8.1.1.1 affiche dans la langue de la
 * locale quand il la connaît (includes/messages : 7, 132, 500, 519, 520, 39,
 * 40, import_genere_liens ; « Tenir compte des notices d'autorités » n'est
 * traduit qu'en en_UK ; de_DE reprend l'anglais, et « Ya » pour oui ; nl_NL
 * garde en français « Générer les liens… »), sinon en français.
 * Tutoiement partout ; pt-BR au « você ». Idempotent.
 * Le détail et les mesures : docs/interop/couverture-pmb.md, tests/pmb/README.md.
 */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const FORMAT = {
  fr: 'UNIMARC Autorités — ISO 2709',
  'pt-BR': 'UNIMARC Autoridades — ISO 2709',
  es: 'UNIMARC Autoridades — ISO 2709',
  en: 'UNIMARC Authorities — ISO 2709',
  ca: 'UNIMARC Autoritats — ISO 2709',
  de: 'UNIMARC Normdaten — ISO 2709',
  el: 'UNIMARC Καθιερωμένοι όροι — ISO 2709',
  eo: 'UNIMARC Aŭtoritatoj — ISO 2709',
  it: 'UNIMARC Autorità — ISO 2709',
  nl: 'UNIMARC Autoriteiten — ISO 2709',
};

const PMB = {
  fr: 'Pour l’importer dans PMB : « Administration > Imports > Exemplaires UNIMARC » (l’onglet voisin, « Notices UNIMARC », ignore les exemplaires), avec la fonction « Catégories RAMEAU » et « Oui » à « Générer les liens entre notices ? » — sans ce « Oui », PMB ne rattache aucun article à sa revue. Le prêteur, le statut et la localisation des exemplaires se choisissent dans ce formulaire.',
  'pt-BR': 'Para importá-lo no PMB: « Administração > Importações > Itens UNIMARC » (« Exemplaires UNIMARC » em um PMB em francês; a aba vizinha, « Registros UNIMARC », ignora os exemplares), com a função « Catégories RAMEAU » e « Sim » em « Gerar vínculo entre registros? » — sem esse « Sim », o PMB não liga nenhum artigo à sua revista. O proprietário, a situação e a localização dos exemplares são escolhidos nesse formulário.',
  es: 'Para importarlo en PMB: « Administración > Importar > Ejemplares UNIMARC » (« Exemplaires UNIMARC » en un PMB en francés; la pestaña vecina, « Registro UNIMARC », ignora los ejemplares), con la función « Catégories RAMEAU » y « Sí » en « ¿Generar enlace entre noticias? » — sin ese « Sí », PMB no enlaza ningún artículo con su revista. El propietario, el estado y la localización de los ejemplares se eligen en ese formulario.',
  en: 'To import it into PMB: « Administration > Imports > UNIMARC Items » (« Exemplaires UNIMARC » in a French PMB; the neighbouring tab, « UNIMARC Records », ignores the items), with the « Catégories RAMEAU » function and « Yes » to « Generate links between records? » — without that « Yes », PMB links no article to its journal. The owner, status and location of the items are chosen in that form.',
  ca: 'Per importar-lo a PMB: « Administració > Importar > Exemplars UNIMARC » (« Exemplaires UNIMARC » en un PMB en francès; la pestanya veïna, « Registres UNIMARC », ignora els exemplars), amb la funció « Catégories RAMEAU » i « Sí » a « Generar els enllaços entre registres ? » — sense aquest « Sí », PMB no enllaça cap article amb la seva revista. El propietari, l’estat i la localització dels exemplars es trien en aquest formulari.',
  de: 'So importierst du sie in PMB: « Administration > Imports > UNIMARC Items » (« Exemplaires UNIMARC » in einem französischen PMB; der benachbarte Reiter « UNIMARC Records » übergeht die Exemplare), mit der Funktion « Catégories RAMEAU » und « Ja » (PMB zeigt « Ya ») bei « Generate links between records? » — ohne dieses « Ja » verknüpft PMB keinen Artikel mit seiner Zeitschrift. Eigentümer, Status und Standort der Exemplare wählst du in diesem Formular.',
  el: 'Για να το εισαγάγεις στο PMB: « Administration > Imports > Exemplaires UNIMARC » (η διπλανή καρτέλα « Notices UNIMARC » αγνοεί τα αντίτυπα), με τη λειτουργία « Catégories RAMEAU » και « Oui » (ναι) στο « Générer les liens entre notices ? » — χωρίς αυτό το « Oui », το PMB δεν συνδέει κανένα άρθρο με το περιοδικό του. Ο κάτοχος, η κατάσταση και η θέση των αντιτύπων επιλέγονται σε αυτή τη φόρμα.',
  eo: 'Por importi ĝin en PMB: « Administration > Imports > Exemplaires UNIMARC » (la najbara langeto « Notices UNIMARC » ignoras la ekzemplerojn), per la funkcio « Catégories RAMEAU » kaj kun « Oui » (jes) ĉe « Générer les liens entre notices ? » — sen tiu « Oui », PMB ligas neniun artikolon al ĝia revuo. La posedanton, la staton kaj la lokon de la ekzempleroj oni elektas en tiu formularo.',
  it: 'Per importarlo in PMB: « Amministrazione > Importa > Esemplari UNIMARC » (« Exemplaires UNIMARC » in un PMB in francese; la scheda vicina, « Schede UNIMARC », ignora gli esemplari), con la funzione « Catégories RAMEAU » e « Sì » a « Generare i collegamenti tra le schede ? » — senza quel « Sì », PMB non collega nessun articolo alla sua rivista. Il proprietario, lo stato e la collocazione degli esemplari si scelgono in quel modulo.',
  nl: 'Zo importeer je het in PMB: « Beheer > Importeren > UNIMARC exemplaren » (« Exemplaires UNIMARC » in een Franse PMB; het tabblad ernaast, « UNIMARC beschrijvingen », slaat de exemplaren over), met de functie « Catégories RAMEAU » en « Ja » bij « Générer les liens entre notices ? » — zonder die « Ja » koppelt PMB geen enkel artikel aan zijn tijdschrift. De eigenaar, de status en de locatie van de exemplaren kies je in dat formulier.',
};

const HINT = {
  fr: 'Dans PMB, importe d’abord ce fichier (Autorités > Import), dans le thésaurus par défaut de PMB, puis le catalogue (format « UNIMARC — ISO 2709 »). PMB rapproche alors les auteurs par leur nom et leurs dates. Dans PMB 8.1, laisse « Non » à « Tenir compte des notices d’autorités » : son formulaire ne transmet pas l’origine choisie.',
  'pt-BR': 'No PMB, importe primeiro este arquivo pelo menu « Autoridades » (« Autorités » em um PMB em francês), no tesauro padrão do PMB, e depois o catálogo (formato « UNIMARC — ISO 2709 »). O PMB associa então os autores pelo nome e pelas datas. No PMB 8.1, deixe « Não » em « Tenir compte des notices d’autorités »: o formulário dele não transmite a origem escolhida.',
  es: 'En PMB, importa primero este archivo desde el menú « Autoridades » (« Autorités » en un PMB en francés), en el tesauro por defecto de PMB, y después el catálogo (formato « UNIMARC — ISO 2709 »). PMB relaciona entonces los autores por el nombre y las fechas. En PMB 8.1, deja « No » en « Tenir compte des notices d’autorités »: su formulario no transmite el origen elegido.',
  en: 'In PMB, import this file first from the « Authorities » menu (« Autorités » in a French PMB), into PMB’s default thesaurus, then the catalogue (« UNIMARC — ISO 2709 » format). PMB then matches authors by name and dates. In PMB 8.1, leave « No » for « Take authority records into account » (« Tenir compte des notices d’autorités » in a French PMB): its form does not pass on the origin you choose.',
  ca: 'A PMB, importa primer aquest fitxer des del menú « Autoritats » (« Autorités » en un PMB en francès), al tesaurus per defecte de PMB, i després el catàleg (format « UNIMARC — ISO 2709 »). PMB relaciona llavors els autors pel nom i les dates. A PMB 8.1, deixa « No » a « Tenir compte des notices d’autorités »: el seu formulari no transmet l’origen triat.',
  de: 'Importiere diese Datei in PMB zuerst über das Menü « Authorities » (« Autorités » in einem französischen PMB), in den Standard-Thesaurus von PMB, danach den Katalog (Format « UNIMARC — ISO 2709 »). PMB ordnet die Autoren dann nach Name und Lebensdaten zu. Lass in PMB 8.1 bei « Tenir compte des notices d’autorités » « Nein » stehen: Sein Formular gibt die gewählte Herkunft nicht weiter.',
  el: 'Στο PMB, εισάγαγε πρώτα αυτό το αρχείο από το μενού « Autorités », στον προεπιλεγμένο θησαυρό του PMB, και έπειτα τον κατάλογο (μορφή « UNIMARC — ISO 2709 »). Το PMB αντιστοιχίζει τότε τους συγγραφείς με το όνομα και τις χρονολογίες τους. Στο PMB 8.1, άφησε « Non » (όχι) στο « Tenir compte des notices d’autorités »: η φόρμα του δεν μεταδίδει την προέλευση που επιλέγεις.',
  eo: 'En PMB, unue importu ĉi tiun dosieron per la menuo « Autorités », en la defaŭltan tezaŭron de PMB, kaj poste la katalogon (formato « UNIMARC — ISO 2709 »). PMB tiam kongruigas la aŭtorojn laŭ nomo kaj datoj. En PMB 8.1, lasu « Non » (ne) ĉe « Tenir compte des notices d’autorités »: ĝia formularo ne transdonas la elektitan devenon.',
  it: 'In PMB, importa prima questo file dal menu « Responsabilità » (« Autorités » in un PMB in francese), nel thesaurus predefinito di PMB, poi il catalogo (formato « UNIMARC — ISO 2709 »). PMB abbina allora gli autori in base al nome e alle date. In PMB 8.1, lascia « No » a « Tenir compte des notices d’autorités »: il suo modulo non trasmette l’origine scelta.',
  nl: 'Importeer dit bestand in PMB eerst via het menu « Autoriteiten » (« Autorités » in een Franse PMB), in de standaardthesaurus van PMB, en daarna de catalogus (formaat « UNIMARC — ISO 2709 »). PMB koppelt de auteurs dan op naam en jaartallen. Laat in PMB 8.1 « Neen » staan bij « Tenir compte des notices d’autorités »: het formulier geeft de gekozen herkomst niet door.',
};

// (29/09) el : « εισήγαγε » est un indicatif (« il a importé ») ; l'impératif est « εισάγαγε ».
const CORRECTIONS = { el: { 'error.import.profile_missing': [['εισήγαγε ξανά', 'εισάγαγε ξανά']] } };

let n = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  if (!FORMAT[loc] || !HINT[loc] || !PMB[loc]) throw new Error(`${loc} : traduction absente`);
  const poser = (cle, v) => { if (j[cle] !== v) { j[cle] = v; n++; } };
  poser('importacoes.export.lote.formatAutorites', FORMAT[loc]);
  poser('importacoes.export.lote.autoritesHint', HINT[loc]);
  // la nouvelle clé se range juste avant l'aide des autorités
  if (!('importacoes.export.lote.pmbHint' in j)) {
    const entrees = Object.entries(j);
    const i = entrees.findIndex(([k]) => k === 'importacoes.export.lote.autoritesHint');
    entrees.splice(i + 1, 0, ['importacoes.export.lote.pmbHint', PMB[loc]]);
    for (const k of Object.keys(j)) delete j[k];
    for (const [k, v] of entrees) j[k] = v;
    n++;
  } else poser('importacoes.export.lote.pmbHint', PMB[loc]);
  for (const [cle, paires] of Object.entries(CORRECTIONS[loc] || {})) {
    for (const [a, b] of paires) if (typeof j[cle] === 'string' && j[cle].includes(a)) { j[cle] = j[cle].replace(a, b); n++; }
  }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
}
console.log(`écrit : ${n}`);
