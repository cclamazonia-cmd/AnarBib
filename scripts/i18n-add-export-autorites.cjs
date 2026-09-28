#!/usr/bin/env node
/**
 * i18n-add-export-autorites.cjs — H25 (28/09/2026), revues contradictoires.
 *
 *  - importacoes.export.lote.formatAutorites : le libellé du format « UNIMARC
 *    Autorités » (il était en dur, en français, dans les 10 locales) ;
 *  - importacoes.export.lote.autoritesHint : la marche à suivre dans PMB, dite
 *    sous le sélecteur quand ce format est choisi (tests/pmb/README.md) —
 *    importer d'abord les autorités, dans le thésaurus par défaut, puis les
 *    notices avec la fonction « Catégories RAMEAU », « Oui » à « Tenir compte
 *    des notices d'autorités » (un choix Oui/Non, pas une case) et l'origine
 *    AnarBib. Les libellés de PMB sont ceux que PMB affiche dans la langue de
 *    la locale quand il la connaît (menu « Autorités » : messages 132 de PMB
 *    8.1.1.1 ; l'option n'est traduite qu'en en_UK), sinon en français. Sans
 *    l'option, PMB ne rapproche les auteurs que par la forme de leur nom.
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
  fr: 'Dans PMB, importe d’abord ce fichier (Autorités > Import), dans le thésaurus par défaut de PMB ; puis importe les notices avec la fonction « Catégories RAMEAU », « Oui » à « Tenir compte des notices d’autorités » et l’origine AnarBib. Sinon, PMB ne rapproche les auteurs que par la forme de leur nom : deux homonymes n’en font qu’un, une forme différente en crée un second.',
  'pt-BR': 'No PMB, importe primeiro este arquivo pelo menu « Autoridades » (« Autorités » em um PMB em francês), no tesauro padrão do PMB; depois importe os registros com a função « Catégories RAMEAU », « Sim » em « Tenir compte des notices d’autorités » e a origem AnarBib. Senão, o PMB só associa os autores pela forma do nome: dois homônimos viram um só, e uma forma diferente cria um segundo.',
  es: 'En PMB, importa primero este archivo desde el menú « Autoridades » (« Autorités » en un PMB en francés), en el tesauro por defecto de PMB; después importa los registros con la función « Catégories RAMEAU », « Sí » en « Tenir compte des notices d’autorités » y el origen AnarBib. Si no, PMB solo relaciona los autores por la forma de su nombre: dos homónimos quedan en uno solo y una forma distinta crea un segundo.',
  en: 'In PMB, import this file first from the « Authorities » menu (« Autorités » in a French PMB), into PMB’s default thesaurus; then import the records with the « Catégories RAMEAU » function, « Yes » to « Take authority records into account » (« Tenir compte des notices d’autorités » in a French PMB) and AnarBib as the origin. Otherwise PMB matches authors only by the form of their name: two namesakes become one, and a different form creates a second.',
  ca: 'A PMB, importa primer aquest fitxer des del menú « Autoritats » (« Autorités » en un PMB en francès), al tesaurus per defecte de PMB; després importa els registres amb la funció « Catégories RAMEAU », « Sí » a « Tenir compte des notices d’autorités » i l’origen AnarBib. Si no, PMB només relaciona els autors per la forma del nom: dos homònims queden en un de sol i una forma diferent en crea un segon.',
  de: 'Importiere diese Datei in PMB zuerst über das Menü « Authorities » (« Autorités » in einem französischen PMB), in den Standard-Thesaurus von PMB; importiere danach die Datensätze mit der Funktion « Catégories RAMEAU », « Ja » bei « Tenir compte des notices d’autorités » und der Herkunft AnarBib. Sonst ordnet PMB Autoren nur nach der Form ihres Namens zu: Zwei Namensgleiche werden zu einem, eine andere Form ergibt einen zweiten.',
  el: 'Στο PMB, εισήγαγε πρώτα αυτό το αρχείο από το μενού « Autorités », στον προεπιλεγμένο θησαυρό του PMB· έπειτα εισήγαγε τις εγγραφές με τη λειτουργία « Catégories RAMEAU », « Oui » (ναι) στο « Tenir compte des notices d’autorités » και προέλευση AnarBib. Αλλιώς το PMB αντιστοιχίζει τους συγγραφείς μόνο με τη μορφή του ονόματός τους: δύο συνώνυμοι γίνονται ένας, και μια διαφορετική μορφή δημιουργεί δεύτερο.',
  eo: 'En PMB, unue importu ĉi tiun dosieron per la menuo « Autorités », en la defaŭltan tezaŭron de PMB; poste importu la registrojn per la funkcio « Catégories RAMEAU », kun « Oui » (jes) ĉe « Tenir compte des notices d’autorités » kaj la deveno AnarBib. Alie PMB kongruigas aŭtorojn nur laŭ la formo de ilia nomo: du samnomuloj fariĝas unu, kaj alia formo kreas duan.',
  it: 'In PMB, importa prima questo file dal menu « Responsabilità » (« Autorités » in un PMB in francese), nel thesaurus predefinito di PMB; poi importa i record con la funzione « Catégories RAMEAU », « Sì » a « Tenir compte des notices d’autorités » e l’origine AnarBib. Altrimenti PMB abbina gli autori solo in base alla forma del nome: due omonimi diventano uno solo e una forma diversa ne crea un secondo.',
  nl: 'Importeer dit bestand in PMB eerst via het menu « Autoriteiten » (« Autorités » in een Franse PMB), in de standaardthesaurus van PMB; importeer daarna de records met de functie « Catégories RAMEAU », « Ja » bij « Tenir compte des notices d’autorités » en AnarBib als herkomst. Anders koppelt PMB auteurs alleen op de vorm van hun naam: twee naamgenoten worden er één, en een andere vorm maakt een tweede aan.',
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
