#!/usr/bin/env node
/**
 * i18n-add-export-autorites.cjs — H25 (28/09/2026), revues contradictoires ;
 * revue de H27 (29/09/2026).
 *
 *  - importacoes.export.lote.formatAutorites : le libellé du format « UNIMARC
 *    Autorités » (il était en dur, en français, dans les 10 locales) ;
 *  - importacoes.export.lote.autoritesHint : la marche à suivre dans PMB, dite
 *    sous le sélecteur quand ce format est choisi (tests/pmb/README.md) —
 *    importer d'abord les autorités, dans le thésaurus par défaut, puis le
 *    catalogue par l'onglet « Exemplaires UNIMARC » (l'onglet voisin, « Notices
 *    UNIMARC », importe les notices mais ignore les 995 sans le dire : revue du
 *    29/09), avec la fonction « Catégories RAMEAU », « Oui » à « Tenir compte
 *    des notices d'autorités » (un choix Oui/Non, pas une case) et l'origine
 *    AnarBib. Les libellés de PMB sont ceux que PMB affiche dans la langue de
 *    la locale quand il la connaît (messages 7, 132, 500, 519 et 520 de PMB
 *    8.1.1.1 ; l'option n'est traduite qu'en en_UK ; de_DE reprend l'anglais),
 *    sinon en français. Sans l'option, PMB rapproche les auteurs par leur nom
 *    ET leurs dates (auteur::import), sans lien vers la fiche.
 * Tutoiement partout ; pt-BR au « você ». Idempotent.
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

const HINT = {
  fr: 'Dans PMB, importe d’abord ce fichier (Autorités > Import), dans le thésaurus par défaut de PMB ; puis importe le catalogue par « Administration > Imports > Exemplaires UNIMARC » (l’onglet voisin, « Notices UNIMARC », ignore les exemplaires), avec la fonction « Catégories RAMEAU », « Oui » à « Tenir compte des notices d’autorités » et l’origine AnarBib. Sinon, PMB rapproche les auteurs par leur nom et leurs dates, sans lien vers leur fiche : deux homonymes sans dates n’en font qu’un, une autre forme ou d’autres dates en créent un second.',
  'pt-BR': 'No PMB, importe primeiro este arquivo pelo menu « Autoridades » (« Autorités » em um PMB em francês), no tesauro padrão do PMB; depois importe o catálogo por « Administração > Importações > Itens UNIMARC » (« Exemplaires UNIMARC » em francês; a aba vizinha, « Registros UNIMARC », ignora os exemplares), com a função « Catégories RAMEAU », « Sim » em « Tenir compte des notices d’autorités » e a origem AnarBib. Senão, o PMB associa os autores pelo nome e pelas datas, sem ligação com a ficha: dois homônimos sem datas viram um só, e outra forma ou outras datas criam um segundo.',
  es: 'En PMB, importa primero este archivo desde el menú « Autoridades » (« Autorités » en un PMB en francés), en el tesauro por defecto de PMB; después importa el catálogo por « Administración > Importar > Ejemplares UNIMARC » (« Exemplaires UNIMARC » en francés; la pestaña vecina, « Registro UNIMARC », ignora los ejemplares), con la función « Catégories RAMEAU », « Sí » en « Tenir compte des notices d’autorités » y el origen AnarBib. Si no, PMB relaciona los autores por el nombre y las fechas, sin enlace con su ficha: dos homónimos sin fechas quedan en uno solo, y otra forma u otras fechas crean un segundo.',
  en: 'In PMB, import this file first from the « Authorities » menu (« Autorités » in a French PMB), into PMB’s default thesaurus; then import the catalogue through « Administration > Imports > UNIMARC Items » (« Exemplaires UNIMARC » in a French PMB; the neighbouring tab, « UNIMARC Records », ignores the items), with the « Catégories RAMEAU » function, « Yes » to « Take authority records into account » (« Tenir compte des notices d’autorités » in a French PMB) and AnarBib as the origin. Otherwise PMB matches authors by name and dates, with no link to their record: two namesakes without dates become one, and another form or other dates create a second.',
  ca: 'A PMB, importa primer aquest fitxer des del menú « Autoritats » (« Autorités » en un PMB en francès), al tesaurus per defecte de PMB; després importa el catàleg per « Administració > Importar > Exemplars UNIMARC » (« Exemplaires UNIMARC » en francès; la pestanya veïna, « Registres UNIMARC », ignora els exemplars), amb la funció « Catégories RAMEAU », « Sí » a « Tenir compte des notices d’autorités » i l’origen AnarBib. Si no, PMB relaciona els autors pel nom i les dates, sense enllaç amb la seva fitxa: dos homònims sense dates queden en un de sol, i una altra forma o unes altres dates en creen un segon.',
  de: 'Importiere diese Datei in PMB zuerst über das Menü « Authorities » (« Autorités » in einem französischen PMB), in den Standard-Thesaurus von PMB; importiere danach den Katalog über « Administration > Imports > UNIMARC Items » (« Exemplaires UNIMARC » in einem französischen PMB; der benachbarte Reiter « UNIMARC Records » übergeht die Exemplare), mit der Funktion « Catégories RAMEAU », « Ja » bei « Tenir compte des notices d’autorités » und der Herkunft AnarBib. Sonst ordnet PMB Autoren nach Name und Lebensdaten zu, ohne Verknüpfung mit ihrem Normdatensatz: Zwei Namensgleiche ohne Daten werden zu einem, eine andere Form oder andere Daten ergeben einen zweiten.',
  el: 'Στο PMB, εισήγαγε πρώτα αυτό το αρχείο από το μενού « Autorités », στον προεπιλεγμένο θησαυρό του PMB· έπειτα εισήγαγε τον κατάλογο από το « Administration > Imports > Exemplaires UNIMARC » (η διπλανή καρτέλα « Notices UNIMARC » αγνοεί τα αντίτυπα), με τη λειτουργία « Catégories RAMEAU », « Oui » (ναι) στο « Tenir compte des notices d’autorités » και προέλευση AnarBib. Αλλιώς το PMB αντιστοιχίζει τους συγγραφείς με το όνομα και τις χρονολογίες τους, χωρίς σύνδεση με την εγγραφή τους: δύο συνώνυμοι χωρίς χρονολογίες γίνονται ένας, ενώ άλλη μορφή ή άλλες χρονολογίες δημιουργούν δεύτερο.',
  eo: 'En PMB, unue importu ĉi tiun dosieron per la menuo « Autorités », en la defaŭltan tezaŭron de PMB; poste importu la katalogon per « Administration > Imports > Exemplaires UNIMARC » (la najbara langeto « Notices UNIMARC » ignoras la ekzemplerojn), per la funkcio « Catégories RAMEAU », kun « Oui » (jes) ĉe « Tenir compte des notices d’autorités » kaj la deveno AnarBib. Alie PMB kongruigas aŭtorojn laŭ nomo kaj datoj, sen ligo al ilia slipo: du samnomuloj sen datoj fariĝas unu, kaj alia formo aŭ aliaj datoj kreas duan.',
  it: 'In PMB, importa prima questo file dal menu « Responsabilità » (« Autorités » in un PMB in francese), nel thesaurus predefinito di PMB; poi importa il catalogo da « Amministrazione > Importa > Esemplari UNIMARC » (« Exemplaires UNIMARC » in francese; la scheda vicina, « Schede UNIMARC », ignora gli esemplari), con la funzione « Catégories RAMEAU », « Sì » a « Tenir compte des notices d’autorités » e l’origine AnarBib. Altrimenti PMB abbina gli autori in base al nome e alle date, senza legame con la loro scheda: due omonimi senza date diventano uno solo, e un’altra forma o altre date ne creano un secondo.',
  nl: 'Importeer dit bestand in PMB eerst via het menu « Autoriteiten » (« Autorités » in een Franse PMB), in de standaardthesaurus van PMB; importeer daarna de catalogus via « Beheer > Importeren > UNIMARC exemplaren » (« Exemplaires UNIMARC » in een Franse PMB; het tabblad ernaast, « UNIMARC beschrijvingen », slaat de exemplaren over), met de functie « Catégories RAMEAU », « Ja » bij « Tenir compte des notices d’autorités » en AnarBib als herkomst. Anders koppelt PMB auteurs op naam en jaartallen, zonder koppeling met hun record: twee naamgenoten zonder jaartallen worden er één, en een andere vorm of andere jaartallen maken een tweede aan.',
};

let n = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  if (!FORMAT[loc] || !HINT[loc]) throw new Error(`${loc} : traduction absente`);
  if (j['importacoes.export.lote.formatAutorites'] !== FORMAT[loc]) { j['importacoes.export.lote.formatAutorites'] = FORMAT[loc]; n++; }
  if (j['importacoes.export.lote.autoritesHint'] !== HINT[loc]) { j['importacoes.export.lote.autoritesHint'] = HINT[loc]; n++; }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
}
console.log(`écrit : ${n}`);
